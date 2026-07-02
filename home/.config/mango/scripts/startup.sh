#!/bin/bash

set -eu

restart_if_running() {
    process_name="$1"
    shift

    if pgrep -x "$process_name" >/dev/null 2>&1; then
        pkill -x "$process_name"
        sleep 0.2
    fi

    "$@" >/dev/null 2>&1 &
}

start_if_missing() {
    process_name="$1"
    shift

    if pgrep -x "$process_name" >/dev/null 2>&1; then
        return
    fi

    "$@" >/dev/null 2>&1 &
}

restart_if_running "dunst" dunst
sleep 0.2
dunstctl set-paused false >/dev/null 2>&1 || true

start_if_missing "awww-daemon" awww-daemon
start_if_missing "xdg-desktop-portal-wlr" /usr/lib/xdg-desktop-portal-wlr

restart_if_running "waybar" waybar

/home/rel/.config/mango/scripts/wallpaper.sh --restore >/dev/null 2>&1 &
