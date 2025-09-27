#!/usr/bin/env bash

get_volume() {
    pamixer --get-volume
}

is_muted() {
    pamixer --get-mute
}

print_status() {
    volume=$(get_volume)
    muted=$(is_muted)
    
    if [ "$muted" = "true" ]; then
        echo "MUTED"
    else
        echo "VOL ${volume}%"
    fi
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