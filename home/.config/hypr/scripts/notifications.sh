#!/usr/bin/env bash
set -u

while true; do
  pkill -f "plasma_waitforname org.freedesktop.Notifications" >/dev/null 2>&1 || true

  if ! pgrep -x dunst >/dev/null 2>&1; then
    dunst >/dev/null 2>&1 &
  fi

  sleep 2
done
