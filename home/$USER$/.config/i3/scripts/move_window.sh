#!/usr/bin/env bash
# --- move windows using % ---

target_pid="$1"
x_p="$2"
y_p="$3"

if [[ -z "$x_p" || -z "$y_p" ]]; then
    echo "missing x or y"
    exit 1
fi

# get screen dimensions
screen_d=$(xdotool getdisplaygeometry)
screen_w=$(echo $screen_d | cut -d " " -f1)
screen_h=$(echo $screen_d | cut -d " " -f2)

# get window dimensions
window_d=$(xdotool getwindowgeometry $target_pid)
window_w=$(echo "$window_d" | grep -oP "Geometry: \K\d+" | head -n1)
window_h=$(echo "$window_d" | grep -oP "Geometry: \d+x\K\d+")

# get new position
new_x=$((x_p * (screen_w - window_w) / 100))
new_y=$((y_p * (screen_h - window_h) / 100))

xdotool windowmove $target_pid $new_x $new_y
echo "pid:$target_pid"