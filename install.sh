#!/bin/bash

DEST="$HOME"
DOT_FOLDER="./home/"

echo "adding perms..."

# ensure perms
for script in $(find . -iname "*.sh"); do
    chmod +x "$script"
done

echo "copying files..."

# create directories
find "$DOT_FOLDER" -type d | while read -r dir; do
    REL="${dir#$DOT_FOLDER/}"
    # skip root folder
    [ "$REL" = "$DOT_FOLDER" ] && continue
    
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