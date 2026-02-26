#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-maximize"
mkdir -p "$state_dir"

dispatch() {
    hyprctl dispatch "$@" >/dev/null
}

state_file() {
    local addr="$1"
    printf '%s/%s.state\n' "$state_dir" "${addr#0x}"
}

read_gap() {
    hyprctl -j getoption general:gaps_out | jq -r '.custom | split(" ")[0]'
}

active_json="$(hyprctl -j activewindow)"
gap="$(read_gap)"
border="$(hyprctl -j getoption general:border_size | jq -r '.int')"
[[ "$gap" =~ ^[0-9]+$ ]]
[[ "$border" =~ ^[0-9]+$ ]]
addr="$(jq -r '.address' <<<"$active_json")"
[[ -n "$addr" && "$addr" != "null" ]] || exit 0

floating="$(jq -r '.floating' <<<"$active_json")"
fullscreen="$(jq -r '.fullscreen' <<<"$active_json")"
monitor_id="$(jq -r '.monitor' <<<"$active_json")"
cur_x="$(jq -r '.at[0]' <<<"$active_json")"
cur_y="$(jq -r '.at[1]' <<<"$active_json")"
cur_w="$(jq -r '.size[0]' <<<"$active_json")"
cur_h="$(jq -r '.size[1]' <<<"$active_json")"

mon_json="$(hyprctl -j monitors | jq -r ".[] | select(.id == $monitor_id)")"
[[ -n "$mon_json" ]] || exit 0

mx="$(jq -r '.x' <<<"$mon_json")"
my="$(jq -r '.y' <<<"$mon_json")"
mw="$(jq -r '.width' <<<"$mon_json")"
mh="$(jq -r '.height' <<<"$mon_json")"
res_left="$(jq -r '.reserved[0]' <<<"$mon_json")"
res_top="$(jq -r '.reserved[1]' <<<"$mon_json")"
res_right="$(jq -r '.reserved[2]' <<<"$mon_json")"
res_bottom="$(jq -r '.reserved[3]' <<<"$mon_json")"

pad=$((gap + border))
max_x=$((mx + res_left + pad))
max_y=$((my + res_top + pad))
max_w=$((mw - res_left - res_right - 2 * pad))
max_h=$((mh - res_top - res_bottom - 2 * pad))

[[ "$floating" == "true" ]] || dispatch togglefloating
[[ "$fullscreen" == "0" ]] || dispatch fullscreenstate 0 0

file="$(state_file "$addr")"

if [[ -f "$file" && "$cur_w" -eq "$max_w" && "$cur_h" -eq "$max_h" ]]; then
    if read -r old_x old_y old_w old_h saved_max_w saved_max_h <"$file" && \
       [[ "$saved_max_w" =~ ^[0-9]+$ && "$saved_max_h" =~ ^[0-9]+$ ]] && \
       [[ "$saved_max_w" -eq "$max_w" && "$saved_max_h" -eq "$max_h" ]]; then
        dispatch resizeactive exact "$old_w" "$old_h"
        dispatch moveactive exact "$old_x" "$old_y"
        rm -f "$file"
        exit 0
    fi
    rm -f "$file"
fi

printf '%s %s %s %s %s %s\n' "$cur_x" "$cur_y" "$cur_w" "$cur_h" "$max_w" "$max_h" >"$file"
dispatch resizeactive exact "$max_w" "$max_h"
dispatch moveactive exact "$max_x" "$max_y"
dispatch bringactivetotop
