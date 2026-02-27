#!/usr/bin/env bash
set -euo pipefail

DOT_HOME_FOLDER="./home"
DOT_ROOT_FOLDER="./root"
DOTS_FILE="dots.txt"
USER_HOME="$HOME"

if [[ "$EUID" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    USER_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi

declare -i SYNCED=0 SKIPPED=0 NEW=0 REMOVED=0
declare -i NEED_ROOT=0
declare -a ENTRIES=()
declare -A COVERED_HOME_FILES=()
declare -A COVERED_ROOT_FILES=()

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

entry_source_path() {
    local scope="$1"
    local rel="$2"
    if [[ "$scope" == "home" ]]; then
        echo "$USER_HOME/$rel"
    else
        echo "/$rel"
    fi
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
    mkdir -p "$DOT_HOME_FOLDER" "$DOT_ROOT_FOLDER"

    if [[ ! -w "$DOT_HOME_FOLDER" || ! -w "$DOT_ROOT_FOLDER" ]]; then
        echo "error: no write permission in repo folders ($DOT_HOME_FOLDER, $DOT_ROOT_FOLDER)"
        exit 1
    fi

    if [[ "$NEED_ROOT" -eq 1 && "$EUID" -ne 0 ]]; then
        echo "error: root entries detected in dots.txt, run with sudo"
        exit 1
    fi
}

sync_file() {
    local user_file="$1"
    local repo_file="$2"
    local rel_name="$3"

    if [[ ! -e "$repo_file" ]]; then
        echo "  new: $rel_name"
        mkdir -p "$(dirname "$repo_file")"
        cp -f --remove-destination "$user_file" "$repo_file"
        ((NEW+=1))
    elif [[ "$user_file" -nt "$repo_file" ]]; then
        echo "  sync: $rel_name"
        cp -f --remove-destination "$user_file" "$repo_file"
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

    case "$mode" in
        literal)
            if [[ -f "$src_base" ]]; then
                sync_file "$src_base" "$repo_base" "$spec"
                return
            fi
            [[ -d "$src_base" ]] || return
            while IFS= read -r -d '' src_file; do
                rel_file="${src_file#"$src_base/"}"
                sync_file "$src_file" "$repo_base/$rel_file" "$base/$rel_file"
            done < <(find "$src_base" -type f -print0)
            ;;
        one)
            [[ -d "$src_base" ]] || return
            while IFS= read -r -d '' src_file; do
                rel_file="${src_file#"$src_base/"}"
                sync_file "$src_file" "$repo_base/$rel_file" "$base/$rel_file"
            done < <(find "$src_base" -maxdepth 1 -type f -print0)
            ;;
        recursive)
            [[ -d "$src_base" ]] || return
            while IFS= read -r -d '' src_file; do
                rel_file="${src_file#"$src_base/"}"
                sync_file "$src_file" "$repo_base/$rel_file" "$base/$rel_file"
            done < <(find "$src_base" -type f -print0)
            ;;
    esac
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

        case "$mode" in
            literal)
                if [[ -f "$repo_base" ]]; then
                    rel_file="${repo_base#"$root/"}"
                    covered_ref["$rel_file"]=1
                elif [[ -d "$repo_base" ]]; then
                    while IFS= read -r -d '' repo_file; do
                        rel_file="${repo_file#"$root/"}"
                        covered_ref["$rel_file"]=1
                    done < <(find "$repo_base" -type f -print0)
                fi
                ;;
            one)
                [[ -d "$repo_base" ]] || continue
                while IFS= read -r -d '' repo_file; do
                    rel_file="${repo_file#"$root/"}"
                    covered_ref["$rel_file"]=1
                done < <(find "$repo_base" -maxdepth 1 -type f -print0)
                ;;
            recursive)
                [[ -d "$repo_base" ]] || continue
                while IFS= read -r -d '' repo_file; do
                    rel_file="${repo_file#"$root/"}"
                    covered_ref["$rel_file"]=1
                done < <(find "$repo_base" -type f -print0)
                ;;
        esac
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

load_entries
preflight_permissions

for entry in "${ENTRIES[@]}"; do
    sync_entry "$entry"
done

cleanup_deleted
cleanup_orphans
echo "new: $NEW | synced: $SYNCED | skipped: $SKIPPED | removed: $REMOVED"
