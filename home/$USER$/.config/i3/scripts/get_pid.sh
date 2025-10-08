#!/usr/bin/env bash

class="$1"
instance="$2"

if [[ -z "$class" || -z "$instance" ]]; then
    echo "missing class or instance"
    exit 1
fi

# get target window
pids=$(xdotool search --class "$class")
target_pid=""

# def not the best way to do this but if works it works
for pid in $pids; do
    n=$(xprop -id $pid WM_CLASS | awk -F '"' '{print $2}')
    # echo "($pid): $n : $instance"
    if [[ "$n" == *"$instance"* ]]; then
        target_pid=$pid
        break
    fi
done

if [[ -z "$target_pid" ]]; then
    echo "window not found"
    exit 1
fi

echo $target_pid