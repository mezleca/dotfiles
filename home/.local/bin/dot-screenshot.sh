#!/usr/bin/env bash
set -uo pipefail

selection=0
delay_ms=0

lock_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_path="$lock_dir/dot-screenshot.lockdir"
if ! mkdir "$lock_path" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$lock_path" 2>/dev/null || true' EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --selection) selection=1; shift ;;
        --delay) delay_ms="$2"; shift 2 ;;
        *) shift ;;
    esac
done

play_sound() {
    local sfx="$HOME/sound_effects/iphone.mp3"
    if [[ -f "$sfx" ]] && command -v mpv >/dev/null 2>&1; then
        mpv --no-terminal --really-quiet "$sfx" >/dev/null 2>&1 &
    fi
}

notify_ok() {
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl notify -1 1200 "rgb(78b0ff)" "Screenshot copied" >/dev/null 2>&1 || true
    fi
}

if [[ "$delay_ms" -gt 0 ]]; then
    sleep "$(awk "BEGIN { printf \"%.3f\", $delay_ms/1000 }")"
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if [[ "$selection" -eq 1 ]]; then
        if command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then
            region="$(slurp)"
            if [[ -n "$region" ]] && grim -g "$region" - | wl-copy; then
                notify_ok
                play_sound
                exit 0
            fi
        fi
        exit 1
    fi

    if command -v grim >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        focused_output="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')"
        if [[ -n "$focused_output" ]] && grim -o "$focused_output" - | wl-copy; then
            notify_ok
            play_sound
            exit 0
        fi
    fi

    if command -v hyprshot >/dev/null 2>&1; then
        if timeout 3s hyprshot -m output -m active --clipboard-only --silent; then
            notify_ok
            play_sound
            exit 0
        fi
    fi
    exit 1
fi

if ! command -v maim >/dev/null 2>&1 || ! command -v xclip >/dev/null 2>&1; then
    exit 1
fi

temp_file="$(mktemp --suffix=.png)"
if [[ "$selection" -eq 1 ]]; then
    maim -s "$temp_file"
else
    maim "$temp_file"
fi

if [[ -s "$temp_file" ]]; then
    xclip -selection clipboard -t image/png < "$temp_file"
    play_sound
fi

rm -f "$temp_file"
