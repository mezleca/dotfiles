#!/usr/bin/env bash

load_owner_context() {
    USER_HOME="$HOME"
    OWNER_USER=""
    OWNER_GROUP=""

    if [[ "$EUID" -eq 0 && -n "${SUDO_USER:-}" ]]; then
        USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        OWNER_USER="$SUDO_USER"
        OWNER_GROUP="$(id -gn "$SUDO_USER")"
    fi
}

entry_scope() {
    local entry="$1"

    if [[ "$entry" == /* ]]; then
        echo "root"
        return
    fi

    echo "home"
}

entry_spec() {
    local entry="$1"

    if [[ "$entry" == '$HOME/'* ]]; then
        echo "${entry#'$HOME/'}"
        return
    fi

    if [[ "$entry" == /* ]]; then
        echo "${entry#/}"
        return
    fi

    echo "$entry"
}

entry_mode() {
    local spec="$1"

    if [[ "$spec" == *"/**" ]]; then
        echo "recursive"
        return
    fi

    if [[ "$spec" == *"/*" ]]; then
        echo "one"
        return
    fi

    echo "literal"
}

entry_base() {
    local spec="$1"
    local mode="$2"

    case "$mode" in
        recursive)
            echo "${spec%/**}"
            ;;
        one)
            echo "${spec%/*}"
            ;;
        *)
            echo "$spec"
            ;;
    esac
}

entry_repo_base() {
    local scope="$1"
    local rel="$2"

    if [[ "$scope" == "home" ]]; then
        echo "$DOT_HOME_FOLDER/$rel"
        return
    fi

    echo "$DOT_ROOT_FOLDER/$rel"
}

entry_source_path() {
    local scope="$1"
    local rel="$2"

    if [[ "$scope" == "home" ]]; then
        echo "$USER_HOME/$rel"
        return
    fi

    echo "/$rel"
}

entry_install_base() {
    entry_source_path "$1" "$2"
}

normalize_entry_line() {
    local line="$1"

    line="${line%%#*}"
    line="${line%$'\r'}"
    line="${line%/}"

    echo "$line"
}

load_entries() {
    local line scope

    ENTRIES=()
    NEED_ROOT=0

    while IFS= read -r line; do
        line="$(normalize_entry_line "$line")"
        [[ -z "$line" ]] && continue

        ENTRIES+=("$line")
        scope="$(entry_scope "$line")"

        if [[ "$scope" == "root" ]]; then
            NEED_ROOT=1
        fi
    done < "$DOTS_FILE"
}

iter_mode_files() {
    local base_path="$1"
    local mode="$2"

    case "$mode" in
        literal)
            if [[ -f "$base_path" ]]; then
                printf '%s\0' "$base_path"
                return
            fi

            [[ -d "$base_path" ]] || return
            find "$base_path" -type f -print0
            ;;
        one)
            [[ -d "$base_path" ]] || return
            find "$base_path" -maxdepth 1 -type f -print0
            ;;
        recursive)
            [[ -d "$base_path" ]] || return
            find "$base_path" -type f -print0
            ;;
    esac
}
