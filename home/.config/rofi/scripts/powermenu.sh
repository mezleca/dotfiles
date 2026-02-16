#!/bin/bash

theme="dark"
POWERMENU_ALLOW_FORCE="${POWERMENU_ALLOW_FORCE:-0}"

while [ "$1" != "" ]; do
    case $1 in
        --theme | -t ) shift
                       theme=$1
                       ;;
    esac
    shift
done

detect_de() {
  pgrep -x awesome   >/dev/null && echo awesome  && return
  pgrep -x i3        >/dev/null && echo i3       && return
  pgrep -x openbox   >/dev/null && echo openbox  && return
  pgrep -x Hyprland  >/dev/null && echo hyprland && return
  echo ""
}

DE="$(detect_de)"

terminate_session() {
  if [ -n "${XDG_SESSION_ID:-}" ]; then
    loginctl terminate-session "$XDG_SESSION_ID" 2>/dev/null && return 0
  fi

  loginctl terminate-user "$USER"
}

logout() {
  close_launcher
  sleep 0.08

  case "$DE" in
    i3)       i3-msg quit ;;
    openbox)  openbox --exit 2>/dev/null || terminate_session ;;
    hyprland) hyprctl dispatch exit 2>/dev/null || terminate_session ;;
    awesome)
      if command -v awesome-client >/dev/null 2>&1; then
        awesome-client "require('gears').timer.start_new(0.12, function() awesome.quit(); return false end)" >/dev/null 2>&1 && return 0
      fi

      terminate_session
      ;;
    *)        terminate_session ;;
  esac
}

close_launcher() {
  pkill -x rofi 2>/dev/null
  pkill -x dmenu 2>/dev/null
  pkill -x wofi 2>/dev/null
}

request_power_action() {
  local action="$1"

  close_launcher
  sleep 0.10

  if perform_power_action "$action"; then
    exit 0
  fi

  notify-send -u critical "power menu" "failed to ${action} (non-force methods failed)."
  exit 1
}

perform_power_action() {
  local action="$1"

  loginctl "$action" && return 0
  systemctl --no-block "$action" && return 0
  systemctl -i --no-block "$action" && return 0

  if [ "$POWERMENU_ALLOW_FORCE" = "1" ]; then
    systemctl --force --force "$action" && return 0
  fi

  return 1
}

OPTIONS="logout\nreboot\nshutdown"

SELECTED=$(printf "%b" "$OPTIONS" | rofi -dmenu -p "" \
    -theme-str "@import \"$HOME/.config/rofi/themes/${theme}.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/themes/common.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/widgets/power.rasi\"")

[[ -z "$SELECTED" ]] && exit 0

case "$SELECTED" in
  logout)   logout ;;
  reboot)   request_power_action reboot ;;
  shutdown) request_power_action poweroff ;;
esac
