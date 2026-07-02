#!/usr/bin/env bash

set -uo pipefail

readonly LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/dot-screenshot.lockdir"
readonly SFX_PATH="$HOME/.local/share/sfx/iphone.mp3"
readonly NOTIFY_TIMEOUT_MS=2000

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

selection=0
delay_ms=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --selection) selection=1; shift ;;
        --delay)     delay_ms="$2"; shift 2 ;;
        *)           shift ;;
    esac
done

has_cmds() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || return 1
    done
}

on_success() {
    if has_cmds notify-send; then
        notify-send --expire-time="$NOTIFY_TIMEOUT_MS" "screenshot" "copied to clipboard"
    fi
    
    if [[ -f "$SFX_PATH" ]] && has_cmds mpv; then
        mpv --no-terminal --really-quiet "$SFX_PATH" >/dev/null 2>&1 &
    fi
}

if [[ "$delay_ms" -gt 0 ]]; then
    sleep "$(awk "BEGIN { printf \"%.3f\", $delay_ms/1000 }")"
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    has_cmds grim wl-copy || exit 1

    if [[ "$selection" -eq 1 ]]; then
        has_cmds slurp || exit 1
        region="$(slurp)"
        if [[ -n "$region" ]] && grim -g "$region" - | wl-copy; then
            on_success
        fi
    else
        if grim - | wl-copy; then
            on_success
        fi
    fi
    exit $?
fi

has_cmds maim xclip || exit 1

temp_file="$(mktemp --suffix=.png)"
trap "rm -f '$temp_file'" EXIT

if [[ "$selection" -eq 1 ]]; then
    maim -s "$temp_file"
else
    maim "$temp_file"
fi

if [[ -s "$temp_file" ]]; then
    xclip -selection clipboard -t image/png < "$temp_file" && on_success
fi
