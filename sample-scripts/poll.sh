#!/bin/bash

# Device ordinal parameter (default 0).
device=${1:-0}

data_endpoint="http://localhost:3000/data"
mining_script="./mine.sh"
poll_interval=2
last_data=""
process_name="miner_$device"

while true; do
    current_data=$(curl -s "$data_endpoint")
    if [ -z "$current_data" ]; then
        echo "Failed to retrieve data. Retrying..."
        sleep "$poll_interval"
        continue
    fi

    if ! pgrep -f "$process_name" > /dev/null || [[ "$current_data" != "$last_data" ]]; then
        last_data="$current_data"
        echo "Restarting $process_name..."
        pkill -f "$process_name"
        bash "$mining_script" "$device" & 
    else
        echo "Poller running with $process_name)..."
    fi
    sleep "$poll_interval"
done
