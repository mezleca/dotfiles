#!/usr/bin/env bash
set -euo pipefail

DOT_HOME_FOLDER="./home"
DOT_ROOT_FOLDER="./root"
DOTS_FILE="dots.txt"
LIB_FOLDER="./lib"

declare -i NEED_ROOT=0 INSTALLED=0 SKIPPED=0

declare -a ENTRIES=()

preflight_permissions() {
    if [[ "$NEED_ROOT" -eq 1 && "$EUID" -ne 0 ]]; then
        echo "error: root entries detected in dots.txt, run with sudo"
        exit 1
    fi
}

ensure_parent_dir() {
    local dst="$1"
    local scope="$2"
    local parent_dir

    parent_dir="$(dirname "$dst")"
    mkdir -p "$parent_dir"

    fix_home_ownership "$parent_dir" "$scope"
}

fix_home_ownership() {
    local target_path="$1"
    local scope="$2"
    local current_path

    if [[ "$scope" != "home" || -z "$OWNER_USER" ]]; then
        return
    fi

    current_path="$target_path"

    while [[ "$current_path" == "$USER_HOME"* && "$current_path" != "$USER_HOME" ]]; do
        chown "$OWNER_USER:$OWNER_GROUP" "$current_path" || true
        current_path="$(dirname "$current_path")"
    done
}

install_file() {
    local src="$1"
    local dst="$2"
    local rel="$3"
    local scope="$4"

    if [[ ! -f "$src" ]]; then
        ((SKIPPED+=1))
        return
    fi

    echo "  install: $rel"
    ensure_parent_dir "$dst" "$scope"
    cp -f --remove-destination "$src" "$dst"
    fix_home_ownership "$dst" "$scope"
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

    if [[ "$mode" == "literal" && -f "$repo_base" ]]; then
        install_file "$repo_base" "$dst_base" "$spec" "$scope"
        return
    fi

    if [[ "$mode" != "literal" && ! -d "$repo_base" ]]; then
        ((SKIPPED+=1))
        return
    fi

    if [[ "$mode" == "literal" && ! -d "$repo_base" ]]; then
        ((SKIPPED+=1))
        return
    fi

    while IFS= read -r -d '' repo_file; do
        rel_file="${repo_file#"$repo_base/"}"
        install_file "$repo_file" "$dst_base/$rel_file" "$base/$rel_file" "$scope"
    done < <(iter_mode_files "$repo_base" "$mode")
}

if [[ ! -f "$DOTS_FILE" ]]; then
    echo "missing dots.txt..."
    exit 1
fi

if [[ ! -f "$LIB_FOLDER/dots.sh" ]]; then
    echo "missing $LIB_FOLDER/dots.sh..."
    exit 1
fi

source "$LIB_FOLDER/dots.sh"
load_owner_context

load_entries
preflight_permissions

for entry in "${ENTRIES[@]}"; do
    install_entry "$entry"
done

echo ""
echo "installed: $INSTALLED | skipped: $SKIPPED"
