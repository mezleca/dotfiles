#!/usr/bin/env bash
set -euo pipefail

# Format: "<match_regex>|<start_command>"
APPS=(
  "otd-daemon|otd-daemon"
  "notifications\\.sh|$HOME/.config/hypr/scripts/notifications.sh"
  "hyprshell run|hyprshell run"
)

mode="${1:-restart}"
[[ "$mode" == "restart" || "$mode" == "ensure" ]]

stop_conflicting_tray_watcher() {
  # Let Quickshell own org.kde.StatusNotifierWatcher.
  pkill -x snixembed >/dev/null 2>&1 || true
}

start_app() {
  local cmd="$1"
  nohup bash -lc "$cmd" >/dev/null 2>&1 &
}

restart_app() {
  local match="$1" cmd="$2"
  pkill -f "$match" >/dev/null 2>&1 || true
  start_app "$cmd"
}

ensure_app() {
  local match="$1" cmd="$2"
  if ! pgrep -f "$match" >/dev/null 2>&1; then
    start_app "$cmd"
  fi
}

stop_conflicting_tray_watcher

for entry in "${APPS[@]}"; do
  match="${entry%%|*}"
  cmd="${entry#*|}"

  case "$mode" in
    ensure) ensure_app "$match" "$cmd" ;;
    restart) restart_app "$match" "$cmd" ;;
  esac
done

stop_conflicting_tray_watcher
