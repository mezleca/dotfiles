#!/bin/bash

DOT_FOLDER="./home"
DEST="$HOME"
DOTS_FILE="dots.txt"

declare -i SYNCED=0 SKIPPED=0 NEW=0 REMOVED=0

sync_file() {
    local user_file="$1"
    local repo_file="$2"
    local rel_name="$3"
    
    if [ ! -f "$repo_file" ]; then
        echo "  new: $rel_name"
        mkdir -p "$(dirname "$repo_file")"
        cp "$user_file" "$repo_file"
        ((NEW++))
    elif [ "$user_file" -nt "$repo_file" ]; then
        echo "  sync: $rel_name"
        cp "$user_file" "$repo_file"
        ((SYNCED++))
    else
        ((SKIPPED++))
    fi
}

process_entry() {
    local entry="$1"
    local depth=""
    local clean_path="$entry"
    
    if [[ "$entry" == *"/**" ]]; then
        depth="recursive"
        clean_path="${entry%/**}"
    elif [[ "$entry" == *"/*" ]]; then
        depth="one"
        clean_path="${entry%/*}"
    fi
    
    local user_path="$DEST/$clean_path"
    local dot_path="$DOT_FOLDER/$clean_path"
    
    if [ -f "$user_path" ]; then
        sync_file "$user_path" "$dot_path" "$clean_path"
        return
    fi
    
    [ ! -d "$user_path" ] && return
    
    echo "checking: $clean_path"
    
    local find_opts="-type f"
    [ "$depth" == "one" ] && find_opts="-maxdepth 1 -type f"
    
    while IFS= read -r user_file; do
        rel_file="${user_file#$user_path/}"
        repo_file="$dot_path/$rel_file"
        sync_file "$user_file" "$repo_file" "$rel_file"
    done < <(find "$user_path" $find_opts)
}

cleanup_orphans() {
    echo ""
    echo "cleaning orphaned entries..."

    declare -A removed

    # iterate bottom up so files are handled before directories
    while IFS= read -r dot_path; do
        rel_path="${dot_path#$DOT_FOLDER/}"

        # skip if already removed by a parent directory
        for parent in "${!removed[@]}"; do
            [[ "$rel_path" == "$parent/"* ]] && continue 2
        done

        local covered=false

        # check if this path is covered by an dots entry
        while IFS= read -r entry; do
            [ -z "$entry" ] && continue

            if [[ "$entry" == */** ]]; then
                entry_dir="${entry%/**}"
            elif [[ "$entry" == */* ]]; then
                entry_dir="${entry%/*}"
            else
                entry_dir="$entry"
            fi

            entry_dir="${entry_dir%/}"

            # covered if
            # - exact match
            # - inside entry_dir
            # - entry_dir is inside this path
            if [[ "$rel_path" == "$entry_dir" ]] \
            || [[ "$rel_path" == "$entry_dir/"* ]] \
            || [[ "$entry_dir" == "$rel_path/"* ]]; then
                covered=true
                break
            fi
        done < "$DOTS_FILE"

        # if covered, never remove
        [ "$covered" = true ] && continue

        # files can be safely removed if orphan
        if [ -f "$dot_path" ]; then
            echo "  remove: $rel_path"
            rm -f "$dot_path"
            removed["$rel_path"]=1
            ((REMOVED++))
            continue
        fi

        # remove ONLY if empty
        if [ -d "$dot_path" ] && [ -z "$(ls -A "$dot_path")" ]; then
            echo "  remove: $rel_path"
            rmdir "$dot_path"
            removed["$rel_path"]=1
            ((REMOVED++))
        fi

    done < <(find "$DOT_FOLDER" -mindepth 1 -depth)
}

if [ ! -f "$DOTS_FILE" ]; then
    echo "missing dots.txt..."
    exit 1
fi

while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    process_entry "$entry"
done < "$DOTS_FILE"

cleanup_orphans

echo ""
echo "new: $NEW | synced: $SYNCED | skipped: $SKIPPED | removed: $REMOVED"
