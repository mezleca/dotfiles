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
  case "${XDG_CURRENT_DESKTOP,,}:${DESKTOP_SESSION,,}" in
    *i3*)       echo i3 ;;
    *openbox*)  echo openbox ;;
    *hyprland*) echo hyprland ;;
    *)
      pgrep -x Hyprland >/dev/null  && echo hyprland  && return
      pgrep -x i3        >/dev/null && echo i3        && return
      pgrep -x openbox   >/dev/null && echo openbox   && return
      echo ""
      ;;
  esac
}

DE="$(detect_de)"

logout() {
  case "$DE" in
    i3)       i3-msg quit ;;
    openbox)  openbox --exit 2>/dev/null || loginctl terminate-user "$USER" ;;
    hyprland) hyprctl dispatch exit 2>/dev/null || loginctl terminate-user "$USER" ;;
    *)        loginctl terminate-user "$USER" ;;
  esac
}

kill_x() {
	pkill -15 X 2>/dev/null || pkill -15 Xorg 2>/dev/null
	sleep 1
}

reboot() {
  kill_x
  systemctl reboot
}

shutdown() {
  kill_x
  systemctl poweroff
}

OPTIONS="logout\nreboot\nshutdown"

SELECTED=$(printf "%b" "$OPTIONS" | rofi -dmenu -p "" \
    -theme-str "@import \"$HOME/.config/rofi/themes/${theme}.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/themes/common.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/widgets/power.rasi\"")

# cancelled
[[ -z "$SELECTED" ]] && exit 0

case "$SELECTED" in
  logout)   logout ;;
  reboot)  reboot ;;
  shutdown) shutdown ;;
esac
