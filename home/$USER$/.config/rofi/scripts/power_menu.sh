#!/bin/bash

lock=""
logout="logout"
shutdown="shutdown"
reboot="reboot"
sleep=""

OPTIONS="$logout\n$reboot\n$shutdown"

SELECTED=$(echo -e "$OPTIONS" | rofi -dmenu -p "" -theme ~/.config/rofi/themes/power.rasi)

case $SELECTED in
    "$logout")
        i3-msg exit
        ;;
    "$reboot")
        systemctl reboot
        ;;
    "$shutdown")
        systemctl poweroff
        ;;
esac
