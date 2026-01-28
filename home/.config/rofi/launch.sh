#!/bin/bash

script=$1
shift

if [[ -z "$script" ]]; then
    echo "usage: $0 <script_name> [--theme dark|light]"
    exit 1
fi

if [[ -f "$HOME/.config/rofi/scripts/${script}.sh" ]]; then
    "$HOME/.config/rofi/scripts/${script}.sh" "$@"
else
    echo "script not found: $script"
    exit 1
fi
