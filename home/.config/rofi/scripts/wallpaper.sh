#!/bin/bash

theme="dark"
wall_folder="$HOME/wallpapers"
cache_dir="$HOME/.cache/rofi-wallpapers"
thumb_width=400
thumb_height=225

while [ "$1" != "" ]; do
    case $1 in
        --theme | -t ) shift
                       theme=$1
                       ;;
        --wallpaper-folder | -w ) shift
                                  wall_folder=$1
                                  ;;
    esac
    shift
done

if [ ! -d "$wall_folder" ]; then
    echo "wallpaper folder not found: $wall_folder"
    exit 1
fi

mkdir -p "$cache_dir"

get_thumb_path() {
    local src="$1"
    local hash=$(echo -n "$src" | md5sum | cut -d' ' -f1)
    echo "$cache_dir/${hash}.png"
}

gen_thumbnails() {
    while IFS= read -r img; do
        thumb=$(get_thumb_path "$img")
        if [ ! -f "$thumb" ] || [ "$img" -nt "$thumb" ]; then
            convert "$img" -resize "${thumb_width}x${thumb_height}^" \
                -gravity center -extent "${thumb_width}x${thumb_height}" \
                "$thumb" 2>/dev/null &
        fi
    done < <(find "$wall_folder" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \))
    wait
}

gen_list() {
    while IFS= read -r img; do
        filename=$(basename "$img")
        thumb=$(get_thumb_path "$img")
        [ -f "$thumb" ] && icon="$thumb" || icon="$img"
        echo -en "${filename}\0icon\x1f${icon}\n"
    done < <(find "$wall_folder" -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) | sort)
}

gen_thumbnails

selected=$(gen_list | rofi -dmenu -p "" \
    -show-icons \
    -theme-str "@import \"$HOME/.config/rofi/themes/${theme}.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/themes/common.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/widgets/wallpaper.rasi\"")

if [ -n "$selected" ]; then
    full_path="${wall_folder}/${selected}"
    
    if [ -f "$full_path" ]; then
        "$HOME/.config/rofi/scripts/set_wallpaper.sh" "$full_path"
    fi
fi


