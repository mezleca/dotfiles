#!/usr/bin/env bash
# --- alternative to move (i3) ---
# @note: as expected, if you have more than 1, thw windows will not stack but overlap each other 

# class:instance:x_percentage:y_percentage:always
declare -a window_definitions=(
    "firefox:Alert:100:100:false" # bottom
    "kitty:kitty:50:50:false"
)

declare -a processed_windows=()

GET_PID_PATH="$HOME/.config/i3/scripts/get_pid.sh"
MOVE_WINDOW_PATH="$HOME/.config/i3/scripts/move_window.sh"

function has_been_processed() {
    local pid=$1
    for processed_pid in "${processed_windows[@]}"; do
        if [ "$processed_pid" == "$pid" ]; then
            return 0
        fi 
    done
    return 1
}

function check_windows() {
    for window_def in "${window_definitions[@]}"; do
        IFS=':' read -r class instance x_perc y_perc always <<< "$window_def"
        
        # get pid using class:instance
        pid=$("$GET_PID_PATH" "$class" "$instance")
        
        # check if window exists and has not been processed yet
        if [[ $? -eq 0 ]] && ! has_been_processed "$pid"; then
            # move it
            echo "($pid): moving to -> $x_perc%, $y_perc%"
            "$MOVE_WINDOW_PATH" "$pid" "$x_perc" "$y_perc"

            # dont save if always is set
            if [[ "$always" != "true" ]]; then
                processed_windows+=("$pid")
            fi
        fi
    done
}

while true; do
    check_windows
    sleep 0.1
done