#!/bin/bash

DEST="$HOME"
DOT_FOLDER="./home"

# ensure perms
echo "adding perms..."
find . -iname "*.sh" -exec chmod +x {} \;

echo "copying files..."

# create directories
find "$DOT_FOLDER" -type d | while read -r dir; do
    REL="${dir#$DOT_FOLDER/}"
    
    # skip root folder
    [ -z "$REL" ] && continue
    
    TARGET="$HOME/$REL"
    [ ! -d "$TARGET" ] && mkdir -p "$TARGET"
done

# copy files
find "$DOT_FOLDER" -type f | while read -r file; do
    REL="${file#$DOT_FOLDER/}"
    TARGET="$HOME/$REL"
    
    echo "copying: $file -> $TARGET"
    cp "$file" "$TARGET"
done

echo "done"
