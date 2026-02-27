#!/usr/bin/env bash
set -euo pipefail

DOT_HOME_FOLDER="./home"
DOT_ROOT_FOLDER="./root"
DOTS_FILE="dots.txt"

USER_HOME="$HOME"
if [[ "$EUID" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi

declare -i NEED_ROOT=0 INSTALLED=0 SKIPPED=0

declare -a ENTRIES=()

entry_scope() {
    local entry="$1"
    if [[ "$entry" == /* ]]; then
        echo "root"
    else
        echo "home"
    fi
}

entry_spec() {
    local entry="$1"
    if [[ "$entry" == '$HOME/'* ]]; then
        echo "${entry#'$HOME/'}"
    elif [[ "$entry" == /* ]]; then
        echo "${entry#/}"
    else
        echo "$entry"
    fi
}

entry_mode() {
    local spec="$1"
    if [[ "$spec" == *"/**" ]]; then
        echo "recursive"
    elif [[ "$spec" == *"/*" ]]; then
        echo "one"
    else
        echo "literal"
    fi
}

entry_base() {
    local spec="$1"
    local mode="$2"
    case "$mode" in
        recursive) echo "${spec%/**}" ;;
        one) echo "${spec%/*}" ;;
        *) echo "$spec" ;;
    esac
}

entry_repo_base() {
    local scope="$1"
    local rel="$2"
    if [[ "$scope" == "home" ]]; then
        echo "$DOT_HOME_FOLDER/$rel"
    else
        echo "$DOT_ROOT_FOLDER/$rel"
    fi
}

entry_install_base() {
    local scope="$1"
    local rel="$2"
    if [[ "$scope" == "home" ]]; then
        echo "$USER_HOME/$rel"
    else
        echo "/$rel"
    fi
}

load_entries() {
    local line scope
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line%$'\r'}"
        [[ -z "$line" ]] && continue

        ENTRIES+=("$line")
        scope="$(entry_scope "$line")"
        if [[ "$scope" == "root" ]]; then
            NEED_ROOT=1
        fi
    done < "$DOTS_FILE"
}

preflight_permissions() {
    if [[ "$NEED_ROOT" -eq 1 && "$EUID" -ne 0 ]]; then
        echo "error: root entries detected in dots.txt, run with sudo"
        exit 1
    fi
}

install_file() {
    local src="$1"
    local dst="$2"
    local rel="$3"

    if [[ ! -f "$src" ]]; then
        ((SKIPPED+=1))
        return
    fi

    echo "  install: $rel"
    mkdir -p "$(dirname "$dst")"
    cp -f --remove-destination "$src" "$dst"
    ((INSTALLED+=1))
}

install_entry() {
    local entry="$1"
    local scope spec mode base repo_base dst_base repo_file rel_file

    scope="$(entry_scope "$entry")"

    spec="$(entry_spec "$entry")"
    mode="$(entry_mode "$spec")"
    base="$(entry_base "$spec" "$mode")"

    repo_base="$(entry_repo_base "$scope" "$base")"
    dst_base="$(entry_install_base "$scope" "$base")"

    case "$mode" in
        literal)
            if [[ -f "$repo_base" ]]; then
                install_file "$repo_base" "$dst_base" "$spec"
                return
            fi
            [[ -d "$repo_base" ]] || { ((SKIPPED+=1)); return; }
            while IFS= read -r -d '' repo_file; do
                rel_file="${repo_file#"$repo_base/"}"
                install_file "$repo_file" "$dst_base/$rel_file" "$base/$rel_file"
            done < <(find "$repo_base" -type f -print0)
            ;;
        one)
            [[ -d "$repo_base" ]] || { ((SKIPPED+=1)); return; }
            while IFS= read -r -d '' repo_file; do
                rel_file="${repo_file#"$repo_base/"}"
                install_file "$repo_file" "$dst_base/$rel_file" "$base/$rel_file"
            done < <(find "$repo_base" -maxdepth 1 -type f -print0)
            ;;
        recursive)
            [[ -d "$repo_base" ]] || { ((SKIPPED+=1)); return; }
            while IFS= read -r -d '' repo_file; do
                rel_file="${repo_file#"$repo_base/"}"
                install_file "$repo_file" "$dst_base/$rel_file" "$base/$rel_file"
            done < <(find "$repo_base" -type f -print0)
            ;;
    esac
}

if [[ ! -f "$DOTS_FILE" ]]; then
    echo "missing dots.txt..."
    exit 1
fi

load_entries
preflight_permissions

for entry in "${ENTRIES[@]}"; do
    install_entry "$entry"
done

echo ""
echo "installed: $INSTALLED | skipped: $SKIPPED"
