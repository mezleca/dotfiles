#!/usr/bin/env bash
set -euo pipefail

DOT_HOME_FOLDER="./home"
DOT_ROOT_FOLDER="./root"
DOTS_FILE="dots.txt"
LIB_FOLDER="./lib"

declare -i SYNCED=0 SKIPPED=0 NEW=0 REMOVED=0
declare -i NEED_ROOT=0
declare -a ENTRIES=()
declare -A COVERED_HOME_FILES=()
declare -A COVERED_ROOT_FILES=()

preflight_permissions() {
    mkdir -p "$DOT_HOME_FOLDER" "$DOT_ROOT_FOLDER"

    if [[ ! -w "$DOT_HOME_FOLDER" || ! -w "$DOT_ROOT_FOLDER" ]]; then
        echo "error: no write permission in repo folders ($DOT_HOME_FOLDER, $DOT_ROOT_FOLDER)"
        exit 1
    fi

    if [[ "$NEED_ROOT" -eq 1 && "$EUID" -ne 0 ]]; then
        echo "error: root entries detected in dots.txt, run with sudo"
        exit 1
    fi

    if [[ -n "$OWNER_USER" ]]; then
        chown -R "$OWNER_USER:$OWNER_GROUP" "$DOT_HOME_FOLDER" || true
    fi
}

fix_repo_home_ownership() {
    local repo_path="$1"
    local scope="$2"

    if [[ "$scope" != "home" || -z "$OWNER_USER" ]]; then
        return
    fi

    chown -R "$OWNER_USER:$OWNER_GROUP" "$repo_path" || true
}

copy_to_repo() {
    local src_file="$1"
    local repo_file="$2"
    local scope="$3"

    mkdir -p "$(dirname "$repo_file")"
    fix_repo_home_ownership "$(dirname "$repo_file")" "$scope"
    cp -f --remove-destination "$src_file" "$repo_file"
    fix_repo_home_ownership "$repo_file" "$scope"
}

sync_file() {
    local source_file="$1"
    local repo_file="$2"
    local rel_name="$3"
    local scope="$4"

    if [[ ! -e "$repo_file" ]]; then
        echo "  new: $rel_name"
        copy_to_repo "$source_file" "$repo_file" "$scope"
        ((NEW+=1))
    elif [[ "$source_file" -nt "$repo_file" ]]; then
        echo "  sync: $rel_name"
        copy_to_repo "$source_file" "$repo_file" "$scope"
        ((SYNCED+=1))
    else
        ((SKIPPED+=1))
    fi
}

sync_entry() {
    local entry="$1"
    local scope spec mode base src_base repo_base src_file rel_file

    scope="$(entry_scope "$entry")"
    spec="$(entry_spec "$entry")"
    mode="$(entry_mode "$spec")"
    base="$(entry_base "$spec" "$mode")"

    src_base="$(entry_source_path "$scope" "$base")"
    repo_base="$(entry_repo_base "$scope" "$base")"

    if [[ "$mode" == "literal" && -f "$src_base" ]]; then
        sync_file "$src_base" "$repo_base" "$spec" "$scope"
        return
    fi

    while IFS= read -r -d '' src_file; do
        rel_file="${src_file#"$src_base/"}"
        sync_file "$src_file" "$repo_base/$rel_file" "$base/$rel_file" "$scope"
    done < <(iter_mode_files "$src_base" "$mode")
}

cleanup_deleted_in_scope() {
    local scope="$1"
    local root="$2"
    local dot_path rel_path src_path

    [[ -d "$root" ]] || return

    while IFS= read -r -d '' dot_path; do
        rel_path="${dot_path#"$root/"}"
        src_path="$(entry_source_path "$scope" "$rel_path")"
        if [[ ! -f "$src_path" ]]; then
            echo "  remove: $rel_path (source deleted)"
            rm -f "$dot_path"
            ((REMOVED+=1))
        fi
    done < <(find "$root" -type f -print0)

    while IFS= read -r -d '' dot_dir; do
        [[ -z "$(ls -A "$dot_dir" 2>/dev/null)" ]] || continue
        rmdir "$dot_dir" 2>/dev/null || true
    done < <(find "$root" -depth -mindepth 1 -type d -print0)
}

build_covered_files_in_scope() {
    local scope="$1"
    local root="$2"
    local map_name="$3"
    local entry entry_scope_cur spec mode base repo_base repo_file rel_file

    [[ -d "$root" ]] || return
    local -n covered_ref="$map_name"
    covered_ref=()

    for entry in "${ENTRIES[@]}"; do
        entry_scope_cur="$(entry_scope "$entry")"
        [[ "$entry_scope_cur" == "$scope" ]] || continue

        spec="$(entry_spec "$entry")"
        mode="$(entry_mode "$spec")"
        base="$(entry_base "$spec" "$mode")"
        repo_base="$(entry_repo_base "$scope" "$base")"

        while IFS= read -r -d '' repo_file; do
            rel_file="${repo_file#"$root/"}"
            covered_ref["$rel_file"]=1
        done < <(iter_mode_files "$repo_base" "$mode")
    done
}

cleanup_orphans_in_scope() {
    local root="$1"
    local map_name="$2"
    local dot_path rel_path
    local -n covered_ref="$map_name"

    [[ -d "$root" ]] || return

    while IFS= read -r -d '' dot_path; do
        rel_path="${dot_path#"$root/"}"
        if [[ -z "${covered_ref["$rel_path"]+x}" ]]; then
            echo "  remove: $rel_path"
            rm -f "$dot_path"
            ((REMOVED+=1))
        fi
    done < <(find "$root" -type f -print0)

    while IFS= read -r -d '' dot_path; do
        rel_path="${dot_path#"$root/"}"
        if [[ -n "${covered_ref["$rel_path"]+x}" ]]; then
            continue
        fi
        [[ -z "$(ls -A "$dot_path" 2>/dev/null)" ]] || continue
        echo "  remove: $rel_path"
        rmdir "$dot_path" 2>/dev/null || true
        ((REMOVED+=1))
    done < <(find "$root" -depth -mindepth 1 -type d -print0)
}

cleanup_deleted() {
    echo "cleaning deleted source files..."
    cleanup_deleted_in_scope "home" "$DOT_HOME_FOLDER"
    cleanup_deleted_in_scope "root" "$DOT_ROOT_FOLDER"
}

cleanup_orphans() {
    echo "cleaning orphaned entries..."
    build_covered_files_in_scope "home" "$DOT_HOME_FOLDER" "COVERED_HOME_FILES"
    build_covered_files_in_scope "root" "$DOT_ROOT_FOLDER" "COVERED_ROOT_FILES"
    cleanup_orphans_in_scope "$DOT_HOME_FOLDER" "COVERED_HOME_FILES"
    cleanup_orphans_in_scope "$DOT_ROOT_FOLDER" "COVERED_ROOT_FILES"
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
    sync_entry "$entry"
done

cleanup_deleted
cleanup_orphans
echo "new: $NEW | synced: $SYNCED | skipped: $SKIPPED | removed: $REMOVED"
