#!/bin/bash

theme="dark"

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

wait_process_death() {
  local process_name="$1"
  local timeout_seconds="${2:-5}"
  local check_interval=0.1
  local elapsed=0
  
  while pgrep -x "$process_name" >/dev/null 2>&1; do
    sleep "$check_interval"
    elapsed=$(echo "$elapsed + $check_interval" | bc)
    
    if (( $(echo "$elapsed >= $timeout_seconds" | bc -l) )); then
      notify-send -u critical "Power Menu" "Failed to close $process_name (timeout after ${timeout_seconds}s)"
      return 1
    fi
  done
  
  return 0
}

DE="$(detect_de)"

logout() {
  case "$DE" in
    i3)       i3-msg quit ;;
    openbox)  openbox --exit 2>/dev/null || loginctl terminate-user "$USER" ;;
    hyprland) hyprctl dispatch exit 2>/dev/null || loginctl terminate-user "$USER" ;;
    awesome)  echo 'awesome.quit()' | awesome-client || pkill awesome ;;
    *)        loginctl terminate-user "$USER" ;;
  esac
}

exit_gracefully() {
  # kill menu first
  pkill -9 rofi dmenu wofi 2>/dev/null
  
  # give rofi a moment to die
  wait_process_death rofi 1
  
  # exit window manager
  logout
  
  # wait for WM to die (3 second timeout)
  if ! wait_process_death "$DE" 3; then
    # force kill if timeout
    pkill -9 "$DE" 2>/dev/null
    sleep 0.2
  fi
  
  sync
}

safe_reboot() {
  exit_gracefully
  systemctl reboot
}

safe_shutdown() {
  exit_gracefully
  systemctl poweroff
}

OPTIONS="logout\nreboot\nshutdown"

SELECTED=$(printf "%b" "$OPTIONS" | rofi -dmenu -p "" \
    -theme-str "@import \"$HOME/.config/rofi/themes/${theme}.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/themes/common.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/widgets/power.rasi\"")

[[ -z "$SELECTED" ]] && exit 0

case "$SELECTED" in
  logout)   logout ;;
  reboot)   safe_reboot ;;
  shutdown) safe_shutdown ;;
esac
