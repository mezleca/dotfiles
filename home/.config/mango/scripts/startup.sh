#!/usr/bin/env bash

set -eu

command_available() {
    local command_name="$1"

    if [[ "$command_name" = /* ]]; then
        [[ -x "$command_name" ]]
        return
    fi

    command -v "$command_name" >/dev/null 2>&1
}

start_if_missing() {
    local process_name="$1"
    local command_name="$2"
    shift 2

    command_available "$command_name" || return 0

    if pgrep -x "$process_name" >/dev/null 2>&1; then
        return 0
    fi

    "$command_name" "$@" >/dev/null 2>&1 &
}

start_portal() {
    local portal_path

    if [[ -x /usr/local/libexec/xdg-desktop-portal-wlr ]]; then
        portal_path=/usr/local/libexec/xdg-desktop-portal-wlr
    elif [[ -x /usr/lib/xdg-desktop-portal-wlr ]]; then
        portal_path=/usr/lib/xdg-desktop-portal-wlr
    else
        return 0
    fi

    start_if_missing "xdg-desktop-por" "$portal_path"
}

systemctl --user import-environment QT_QPA_PLATFORMTHEME XDG_CURRENT_DESKTOP XDG_SESSION_TYPE WAYLAND_DISPLAY \
    >/dev/null 2>&1 || true
dbus-update-activation-environment --systemd QT_QPA_PLATFORMTHEME XDG_CURRENT_DESKTOP XDG_SESSION_TYPE WAYLAND_DISPLAY \
    >/dev/null 2>&1 || true

if pgrep -x noctalia >/dev/null 2>&1; then
    noctalia msg config-reload >/dev/null 2>&1 || true
else
    start_if_missing noctalia noctalia --daemon
fi

start_if_missing "wayland-pipewir" wayland-pipewire-idle-inhibit
start_portal
