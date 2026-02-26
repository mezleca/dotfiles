#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hypr-maximize"
mkdir -p "$state_dir"

dispatch() {
  hyprctl dispatch "$@" >/dev/null
}

read_active_window() {
  hyprctl -j activewindow
}

get_monitor_info() {
  local monitor_id="$1"
  hyprctl -j monitors | jq -r ".[] | select(.id == $monitor_id)"
}

approx_equal() {
  local a="$1" b="$2"
  local tolerance=6
  local diff=$(( a > b ? a - b : b - a ))
  (( diff <= tolerance ))
}

state_file() {
  local addr="$1"
  printf '%s/%s.state\n' "$state_dir" "${addr#0x}"
}

store_geometry() {
  local file="$1" x="$2" y="$3" w="$4" h="$5"
  printf '%s %s %s %s\n' "$x" "$y" "$w" "$h" >"$file"
}

restore_geometry() {
  local file="$1"
  read -r x y w h <"$file"
  dispatch resizeactive exact "$w" "$h"
  dispatch moveactive exact "$x" "$y"
  rm -f "$file"
}

main() {
  local active_json addr monitor_id floating fullscreen
  active_json="$(read_active_window)"
  addr="$(jq -r '.address' <<<"$active_json")"
  [[ -n "$addr" && "$addr" != "null" ]] || exit 0

  monitor_id="$(jq -r '.monitor' <<<"$active_json")"
  floating="$(jq -r '.floating' <<<"$active_json")"
  fullscreen="$(jq -r '.fullscreen' <<<"$active_json")"
  local cur_x cur_y cur_w cur_h
  cur_x="$(jq -r '.at[0]' <<<"$active_json")"
  cur_y="$(jq -r '.at[1]' <<<"$active_json")"
  cur_w="$(jq -r '.size[0]' <<<"$active_json")"
  cur_h="$(jq -r '.size[1]' <<<"$active_json")"

  local mon_json
  mon_json="$(get_monitor_info "$monitor_id")"
  [[ -n "$mon_json" ]] || exit 0

  local mx my mw mh res_left res_top res_right res_bottom
  mx="$(jq -r '.x' <<<"$mon_json")"
  my="$(jq -r '.y' <<<"$mon_json")"
  mw="$(jq -r '.width' <<<"$mon_json")"
  mh="$(jq -r '.height' <<<"$mon_json")"
  res_left="$(jq -r '.reserved[0]' <<<"$mon_json")"
  res_top="$(jq -r '.reserved[1]' <<<"$mon_json")"
  res_right="$(jq -r '.reserved[2]' <<<"$mon_json")"
  res_bottom="$(jq -r '.reserved[3]' <<<"$mon_json")"

  local border gaps pad max_x max_y max_w max_h
  border="$(hyprctl getoption general:border_size | awk '/int:/ {print $2}')"
  gaps="$(hyprctl getoption general:gaps_out | awk '/int:/ {print $2}')"
  pad=$((border + gaps))

  max_x=$((mx + res_left + pad))
  max_y=$((my + res_top + pad))
  max_w=$((mw - res_left - res_right - 2 * pad))
  max_h=$((mh - res_top - res_bottom - 2 * pad))
  (( max_w < 100 )) && max_w=100
  (( max_h < 100 )) && max_h=100

  [[ "$floating" == "true" ]] || dispatch togglefloating
  local file
  file="$(state_file "$addr")"

  if [[ -f "$file" ]]; then
    if approx_equal "$cur_w" "$max_w" && approx_equal "$cur_h" "$max_h"; then
      [[ "$fullscreen" != "0" ]] && dispatch fullscreen 1
      restore_geometry "$file"
      exit 0
    fi
  fi

  store_geometry "$file" "$cur_x" "$cur_y" "$cur_w" "$cur_h"
  [[ "$fullscreen" != "0" ]] && dispatch fullscreen 1
  dispatch resizeactive exact "$max_w" "$max_h"
  dispatch moveactive exact "$max_x" "$max_y"
}

main
