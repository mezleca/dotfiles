#!/usr/bin/env bash

set -eu

readonly WAYBAR_CONFIG_PATH="${HOME}/.config/waybar/labwc/config.jsonc"
readonly WAYBAR_STYLE_PATH="${HOME}/.config/waybar/labwc/style.css"
readonly HYPRLOCK_SCRIPT="${HOME}/.config/labwc/hyprlock.sh"
readonly WALLPAPER_MANAGER_PATH="${HOME}/.local/bin/wallpaper-manager.sh"

command_available() {
    local command_name="$1"

    if [[ "$command_name" = /* ]]; then
        [[ -x "$command_name" ]]
        return
    fi

    command -v "$command_name" >/dev/null 2>&1
}

restart_if_present() {
    local process_name="$1"
    local command_name="$2"
    shift 2

    command_available "$command_name" || return 0

    if pgrep -x "$process_name" >/dev/null 2>&1; then
        pkill -x "$process_name" || true
        sleep 0.2
    fi

    "$command_name" "$@" >/dev/null 2>&1 &
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

    start_if_missing "xdg-desktop-portal-wlr" "$portal_path"
}

restart_if_present "waybar" waybar \
    -c "$WAYBAR_CONFIG_PATH" \
    -s "$WAYBAR_STYLE_PATH"
start_if_missing "dunst" dunst
start_if_missing "awww-daemon" awww-daemon
start_if_missing "wayland-pipewire-idle-inhibit" wayland-pipewire-idle-inhibit
start_if_missing "swayidle" swayidle -w \
    timeout 600 "$HYPRLOCK_SCRIPT" \
    before-sleep "$HYPRLOCK_SCRIPT"
start_portal

if command_available gnome-keyring-daemon; then
    if ! pgrep -x gnome-keyring-daemon >/dev/null 2>&1; then
        eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)"
        export GNOME_KEYRING_CONTROL
    fi

    printf '\n' | gnome-keyring-daemon --unlock >/dev/null 2>&1 || true
fi

if [[ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]] && \
    ! pgrep -x polkit-gnome-authentication-agent-1 >/dev/null 2>&1; then
    /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
        >/dev/null 2>&1 &
fi

if command_available dunstctl; then
    dunstctl set-paused false >/dev/null 2>&1 || true
fi

if command_available "$WALLPAPER_MANAGER_PATH"; then
    "$WALLPAPER_MANAGER_PATH" --restore >/dev/null 2>&1 &
fi
