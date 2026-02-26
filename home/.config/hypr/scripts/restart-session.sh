#!/usr/bin/env bash
set -euo pipefail

hyprctl reload >/dev/null 2>&1 || true
"$HOME/.config/hypr/scripts/processes.sh" restart >/dev/null 2>&1 || true
