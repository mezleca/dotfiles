#!/usr/bin/env bashP

poweroff="Shut Down"
reboot="Restart"
suspend="Sleep"
logout="Log Out"

# Rofi CMD
rofi_cmd() {
	rofi -dmenu \
		-mesg "Power Menu" \
}

# Pass variables to rofi dmenu
run_rofi() {
	echo -e "$poweroff\n$reboot\n$suspend\n$logout" | rofi_cmd
}

menu_option="$(run_rofi)"
if [[ ! -z "$menu_option" ]]
then
	case $menu_option in 
		$poweroff)
		poweroff
			;;
		$reboot)
		reboot
			;;
		$suspend)
		systemctl suspend
			;;
		$logout)
		hyprctl dispatch exit
			;;
	esac
fi
