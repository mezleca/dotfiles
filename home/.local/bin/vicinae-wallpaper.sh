#!/bin/bash

WALL_FOLDER="$HOME/wallpapers"
LAST_WALL_FILE="$HOME/.cache/last-wallpaper"
restore=0

while [ "$1" != "" ]; do
    case $1 in
        --wallpaper-folder | -w )
            shift
            WALL_FOLDER="$1"
            ;;
        --restore | -r )
            restore=1
            ;;
    esac
    shift
done

if [ ! -d "$WALL_FOLDER" ]; then
    notify-send "wallpaper folder not found: $WALL_FOLDER"
    exit 1
fi

find_wallpapers() {
    find "$WALL_FOLDER" -maxdepth 1 -type f \( \
        -name "*.jpg" -o -name "*.jpeg" -o \
        -name "*.png" -o -name "*.webp" \
    \) | sort
}

apply_wallpaper() {
    local path="$1"
    
    echo "applying: $path"
    echo "$path" > "$LAST_WALL_FILE"
    
    feh --bg-fill $path
}

restore_wallpaper() {
    local last=""

    if [ -f "$LAST_WALL_FILE" ]; then
        last=$(cat "$LAST_WALL_FILE")
    fi

    # use last wallpaper if it still exists
    if [ -n "$last" ] && [ -f "$last" ]; then
        echo "restoring last wallpaper: $last"
        apply_wallpaper "$last"
        return
    fi

    # fallback to first wallpaper in folder
    local first
    first=$(find_wallpapers | head -n 1)

    if [ -z "$first" ]; then
        echo "no wallpapers found in $WALL_FOLDER"
        exit 1
    fi

    echo "fallback to first wallpaper: $first"
    apply_wallpaper "$first"
}

pick_wallpaper() {
    local selected
    selected=$(find_wallpapers | vicinae dmenu -p "Pick a wallpaper...")

    if [ -z "$selected" ]; then
        exit 0
    fi

    if [ ! -f "$selected" ]; then
        notify-send "file not found: $selected"
        exit 1
    fi

    apply_wallpaper "$selected"
}

if [ "$restore" -eq 1 ]; then
    restore_wallpaper
else
    pick_wallpaper
fi
