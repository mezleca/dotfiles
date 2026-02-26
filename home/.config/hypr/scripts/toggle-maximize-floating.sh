#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-maximize"
mkdir -p "$state_dir"

dispatch() { hyprctl dispatch "$@" >/dev/null; }

read -r addr monitor_id fullscreen_state floating cur_x cur_y cur_w cur_h <<<"$(
  hyprctl -j activewindow | jq -r '[.address,.monitor,.fullscreen,.floating,.at[0],.at[1],.size[0],.size[1]] | @tsv'
)"

if [[ -z "${addr:-}" || "$addr" == "null" ]]; then
  exit 0
fi

key="${addr#0x}"
state_file="$state_dir/$key"

if [[ -f "$state_file" ]]; then
  read -r old_x old_y old_w old_h < "$state_file"

  if [[ "$fullscreen_state" != "0" ]]; then
    dispatch fullscreen 1
  fi

  dispatch resizeactive exact "$old_w" "$old_h"
  dispatch moveactive exact "$old_x" "$old_y"
  rm -f "$state_file"
  exit 0
fi

printf '%s %s %s %s\n' "$cur_x" "$cur_y" "$cur_w" "$cur_h" > "$state_file"

if [[ "$fullscreen_state" != "0" ]]; then
  dispatch fullscreen 1
fi

if [[ "$floating" != "true" ]]; then
  dispatch togglefloating
fi

read -r mx my mw mh res_left res_top res_right res_bottom <<<"$(
  hyprctl -j monitors |
    jq -r ".[] | select(.id == $monitor_id) | [.x,.y,.width,.height,.reserved[0],.reserved[1],.reserved[2],.reserved[3]] | @tsv"
)"

if [[ -z "${mx:-}" ]]; then
  exit 0
fi

border="$(hyprctl getoption general:border_size | awk '/int:/ {print $2}')"
gaps_out="$(hyprctl getoption general:gaps_out | awk '/int:/ {print $2}')"
pad=$((border + gaps_out))

max_x=$((mx + res_left + pad))
max_y=$((my + res_top + pad))
max_w=$((mw - res_left - res_right - (2 * pad)))
max_h=$((mh - res_top - res_bottom - (2 * pad)))

if (( max_w < 100 )); then max_w=100; fi
if (( max_h < 100 )); then max_h=100; fi

dispatch resizeactive exact "$max_w" "$max_h"
dispatch moveactive exact "$max_x" "$max_y"
