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

TEMP=$(mktemp --suffix=.png)
maim $ARGS "$TEMP"

if [[ $? -eq 0 ]]; then
    cat "$TEMP" | xclip -selection clipboard -t image/png
    mpv "$HOME/sound_effects/iphone.mp3"
fi

rm -f "$TEMP"
