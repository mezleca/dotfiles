#!/usr/bin/env bash
ARGS=""
DELAY_MS=0

# optional: -i $(xdotool getactivewindow)

# parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --selection)
            ARGS="-s"
            shift
            ;;
        --delay)
            DELAY_MS="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# apply delay if specified
if [[ $DELAY_MS -gt 0 ]]; then
    DELAY_SECONDS=$(echo "scale=3; $DELAY_MS / 1000" | bc)
    echo "sleeping for $DELAY_SECONDS secs"
    sleep $DELAY_SECONDS
fi

maim $ARGS | xclip -selection clipboard -t image/png
mpv "$HOME/.config/i3/stuff/iphone.mp3"
