#!/bin/bash

theme="dark"

while [ "$1" != "" ]; do
    case $1 in
        --theme | -t ) shift
                       theme=$1
                       ;;
    esac
    shift
done

rofi -modi drun -show drun \
    -drun-display-format "{name}" \
    -display-drun "" \
    -theme-str "@import \"$HOME/.config/rofi/themes/${theme}.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/themes/common.rasi\"" \
    -theme-str "@import \"$HOME/.config/rofi/widgets/drun.rasi\""
