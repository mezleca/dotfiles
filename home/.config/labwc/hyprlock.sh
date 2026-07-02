#!/usr/bin/env sh

set -eu

readonly HYPRLOCK_BACKGROUNDS="${HOME}/.config/hypr/hyprlock-backgrounds.conf"

# generates one "background {}" block per output, pointing at whatever awww is currently displaying there
awww query | awk -F': ' '/image:/ {
    printf "background {\n  monitor = %s\n  path = %s\n  brightness = 0.55\n  contrast = 0.9\n}\n", $2, $NF
}' > "$HYPRLOCK_BACKGROUNDS"

exec hyprlock
