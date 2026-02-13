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

DE="$(detect_de)"

logout() {
  case "$DE" in
    i3)       i3-msg quit ;;
    openbox)  openbox --exit 2>/dev/null || loginctl terminate-user "$USER" ;;
    hyprland) hyprctl dispatch exit 2>/dev/null || loginctl terminate-user "$USER" ;;
    awesome)  echo 'awesome.quit()' | awesome-client || pkill -x awesome ;;
    *)        loginctl terminate-user "$USER" ;;
  esac
}

close_launcher() {
  pkill -x rofi 2>/dev/null
  pkill -x dmenu 2>/dev/null
  pkill -x wofi 2>/dev/null
}

safe_reboot() {
  close_launcher

  if ! systemctl --no-block reboot; then
    if ! reboot; then
      notify-send -u critical "power menu" "failed to reboot (systemctl/reboot)."
    fi
  fi
}

safe_shutdown() {
  close_launcher

  if ! systemctl --no-block poweroff; then
    if ! poweroff; then
      notify-send -u critical "power menu" "failed to power off (systemctl/poweroff)."
    fi
  fi
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
