#!/bin/bash

CACHE_FILE="$HOME/.cache/current_wallpaper"

if [[ "$1" == "--restore" ]]; then
    if [[ -f "$CACHE_FILE" ]]; then
        WALLPAPER=$(cat "$CACHE_FILE")
        if [[ -f "$WALLPAPER" ]]; then
            feh --bg-fill "$WALLPAPER"
            exit 0
        fi
    fi
    exit 1
fi

WALLPAPER="$1"

if [[ -f "$WALLPAPER" ]]; then
    feh --bg-fill "$WALLPAPER"
    echo "$WALLPAPER" > "$CACHE_FILE"
else
    echo "wallpaper file not found: $WALLPAPER"
    exit 1
fi
