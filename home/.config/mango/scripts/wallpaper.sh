#!/bin/bash

set -eu

readonly WALLPAPER_DIR="${HOME}/wallpapers"
readonly LAST_WALLPAPER_FILE="${HOME}/.cache/last-wallpaper"
readonly THUMB_DIR="${HOME}/.cache/mango/wallpaper-thumbs"
readonly THUMB_SIZE="160x90"

restore_mode=0
select_mode=0
wallpaper_dir="$WALLPAPER_DIR"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --restore|-r)
            restore_mode=1
            ;;
        --select|-s)
            select_mode=1
            ;;
        --wallpaper-folder|-w)
            shift
            wallpaper_dir="$1"
            ;;
    esac

    shift
done

require_command() {
    if command -v "$1" >/dev/null 2>&1; then
        return
    fi

    notify-send "mango wallpaper" "$1 is not installed."
    exit 1
}

list_wallpapers() {
    find "$wallpaper_dir" -maxdepth 1 -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \
    \) | sort
}

thumbnail_for() {
    wallpaper_path="$1"
    thumbnail_hash="$(printf '%s' "$wallpaper_path" | sha256sum | awk '{print $1}')"
    thumbnail_path="${THUMB_DIR}/${thumbnail_hash}.png"

    mkdir -p "$THUMB_DIR"

    if [ ! -f "$thumbnail_path" ] || [ "$wallpaper_path" -nt "$thumbnail_path" ]; then
        magick "$wallpaper_path" \
            -auto-orient \
            -thumbnail "${THUMB_SIZE}^" \
            -gravity center \
            -extent "$THUMB_SIZE" \
            "$thumbnail_path"
    fi

    printf '%s\n' "$thumbnail_path"
}

start_awww_daemon() {
    require_command "awww"
    require_command "awww-daemon"

    if pgrep -x "awww-daemon" >/dev/null 2>&1; then
        return
    fi

    awww-daemon >/dev/null 2>&1 &
    sleep 0.3
}

apply_wallpaper() {
    wallpaper_path="$1"

    mkdir -p "$(dirname "$LAST_WALLPAPER_FILE")"
    printf '%s\n' "$wallpaper_path" > "$LAST_WALLPAPER_FILE"

    start_awww_daemon
    awww img "$wallpaper_path"
}

pick_wallpaper() {
    require_command "yad"

    mapfile -t wallpapers < <(list_wallpapers)

    if [ "${#wallpapers[@]}" -eq 0 ]; then
        notify-send "mango wallpaper" "no wallpapers found in ${wallpaper_dir}"
        exit 1
    fi

    rows=()

    for wallpaper_path in "${wallpapers[@]}"; do
        rows+=("$(thumbnail_for "$wallpaper_path")" "$(basename "$wallpaper_path")" "$wallpaper_path")
    done

    selected_wallpaper="$(
        yad \
            --list \
            --title="select wallpaper" \
            --width=920 \
            --height=620 \
            --button="cancel:1" \
            --button="apply:0" \
            --column="preview:IMG" \
            --column="name:TEXT" \
            --column="path:HD" \
            --print-column=3 \
            --separator="" \
            --search-column=2 \
            --ellipsize-cols=2 \
            "${rows[@]}" | tr -d '\r\n' | sed 's/|*$//'
    )" || exit 0

    if [ -z "$selected_wallpaper" ]; then
        exit 0
    fi

    if [ ! -f "$selected_wallpaper" ]; then
        notify-send "mango wallpaper" "selected wallpaper does not exist: $selected_wallpaper"
        exit 1
    fi

    apply_wallpaper "$selected_wallpaper"
}

restore_wallpaper() {
    if [ -f "$LAST_WALLPAPER_FILE" ]; then
        last_wallpaper="$(cat "$LAST_WALLPAPER_FILE")"

        if [ -f "$last_wallpaper" ]; then
            apply_wallpaper "$last_wallpaper"
            return
        fi
    fi

    first_wallpaper="$(list_wallpapers | sed -n '1p')"

    if [ -z "$first_wallpaper" ]; then
        notify-send "mango wallpaper" "no wallpapers found in ${wallpaper_dir}"
        exit 1
    fi

    apply_wallpaper "$first_wallpaper"
}

if [ "$restore_mode" -eq 1 ]; then
    restore_wallpaper
    exit 0
fi

if [ "$select_mode" -eq 1 ]; then
    pick_wallpaper
    exit 0
fi

restore_wallpaper
