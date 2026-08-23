#!/usr/bin/env bash

set -uo pipefail

lock_dir="${XDG_RUNTIME_DIR:-/tmp}/dot-screenshot.lockdir"
sfx="$HOME/.local/share/sfx/iphone.mp3"
selection=0
delay_ms=0

while (($#)); do
    case "$1" in
        --selection) selection=1 ;;
        --delay)
            [[ ${2:-} =~ ^[0-9]+$ ]] || exit 2
            delay_ms="$2"
            shift
            ;;
        *) exit 2 ;;
    esac
    shift
done

mkdir "$lock_dir" 2>/dev/null || exit 0
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT

if ((delay_ms)); then
    printf -v delay '%d.%03d' "$((delay_ms / 1000))" "$((delay_ms % 1000))"
    sleep "$delay"
fi

if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    if ((selection)); then
        region="$(slurp)" || exit 0
        [[ -n $region ]] || exit 0

        if command -v satty >/dev/null; then
            image="$(mktemp --suffix=.png)"
            grim -g "$region" "$image" || { rm -f "$image"; exit 1; }

            (
                trap 'rm -f "$image"' EXIT
                satty \
                    --filename "$image" \
                    --floating-hack \
                    --initial-tool=brush \
                    --copy-command=wl-copy \
                    --actions-on-enter=save-to-clipboard \
                    --actions-on-escape=exit \
                    --early-exit=copy \
                    --disable-notifications
            ) >/dev/null 2>&1 &
        else
            grim -g "$region" - | wl-copy
        fi
    else
        grim - | wl-copy
    fi
    result=$?
else
    image="$(mktemp --suffix=.png)"
    if ((selection)); then
        maim -s "$image"
    else
        maim "$image"
    fi
    result=$?

    if ((result == 0)) && [[ -s $image ]]; then
        xclip -selection clipboard -t image/png < "$image"
        result=$?
    fi
    rm -f "$image"
fi

if ((result == 0)) && [[ -f $sfx ]] && command -v mpv >/dev/null; then
    mpv --no-terminal --really-quiet "$sfx" >/dev/null 2>&1 &
fi

exit "$result"
