#!/usr/bin/env bash

get_icon() {
    muted=$(is_muted)
    if [ "$muted" = "true" ]; then
        echo ""
        return
    fi

    vol=$(get_volume)
    vol=${vol:-0}
    vol=${vol%.*}

    if [ "$vol" -le 0 ]; then
        echo "   "
    elif [ "$vol" -lt 30 ]; then
        echo "   "
    elif [ "$vol" -lt 70 ]; then
        echo "   "
    else
        echo "   "
    fi
}

get_volume() {
    pamixer --get-volume
}

is_muted() {
    pamixer --get-mute
}

print_status() {
    volume=$(get_volume)
    icon=$(get_icon)

    echo "$icon $volume%"
}

case $1 in
    "--up")
        pamixer --increase 5
        ;;
    "--down")
        pamixer --decrease 5
        ;;
    "--mute")
        pamixer --toggle-mute
        ;;
    "--pavucontrol")
        pavucontrol &
        ;;
    *)
        print_status
        ;;
esac