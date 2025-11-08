#!/usr/bin/env bash

# Fix1
killall kded6

# Terminate already running bar instances
killall -q waybar

# Wait until the waybar processes have been shut down
while pgrep -x waybar >/dev/null; do sleep 1; done

# Launch Waybar
snixembed --fork &
waybar &
