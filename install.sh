#!/bin/bash

DEST="$HOME"
DOT_FOLDER="./home/"

echo $DOT_FOLDER

echo "adding perms..."

# ensure perms
for script in $(find . -iname "*.sh"); do
    chmod +x $script
done

# copy shit

echo "copying files..."

for base_dir in $(find $DOT_FOLDER); do
    # ignore symbolic links
    [ -L "$base_dir" ] && continue

    REL=$(echo "$base_dir" | awk -v sep="$DOT_FOLDER" '{split($0, arr, sep); print arr[2]}')
    FINAl="$HOME/$REL"

    cp -r "$base_dir" "$HOME" >/dev/null 2>&1
done

echo "done"