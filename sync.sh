#!/bin/bash

DOT_FOLDER="./home"
DEST="$HOME"

echo "checking for modified files..."

SYNCED_COUNT=0
SKIPPED_COUNT=0

while IFS= read -r repo_file; do
    REL="${repo_file#$DOT_FOLDER/}"
    USER_FILE="$DEST/$REL"
    
    # check if file exists in user home
    if [ ! -f "$USER_FILE" ]; then
        echo "skipped: $REL (not found in \$HOME)"
        ((SKIPPED_COUNT++))
        continue
    fi
    
    REPO_TIME=$(stat -c %Y "$repo_file" 2>/dev/null)
    USER_TIME=$(stat -c %Y "$USER_FILE" 2>/dev/null)
    
    # sync if user file is newer
    if [ "$USER_TIME" -gt "$REPO_TIME" ]; then
        echo "syncing: $REL"
        cp "$USER_FILE" "$repo_file"
        ((SYNCED_COUNT++))
    else
        ((SKIPPED_COUNT++))
    fi
done < <(find "$DOT_FOLDER" -type f)

echo ""
echo "sync completed"
echo "synced: $SYNCED_COUNT files"
echo "skipped: $SKIPPED_COUNT files"
