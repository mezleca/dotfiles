#!/usr/bin/env bash

ARGS=""

if [ "$1" == "--window" ]; then
    ARGS="-i $(xdotool getactivewindow)"
fi

# fallback to default
if [[ $ARGS == "" ]]; then
    ARGS="-s"
fi

maim $ARGS | xclip -selection clipboard -t image/png
mpv "$HOME/.config/i3/stuff/iphone.mp3"