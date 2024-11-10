#!/bin/bash

# Device ordinal parameter (default 0).
device=${1:-0}

data_endpoint="http://localhost:3000/data"
mining_script="./mine.sh"
poll_interval=2
last_data=""
process_name="miner_$device"
message="V2"

# Specify valid miner Stellar addresses (Don't forget trustline to FCM!).
miners=(
  # "GBGSMV..."
  # "GASKJI..."
  # "GBRLWH..."
)
current_miner_index=0
shuffle_miners() {
    for ((i=${#miners[@]}-1; i>0; i--)); do
        j=$((RANDOM % (i+1)))
        temp="${miners[i]}"
        miners[i]="${miners[j]}"
        miners[j]="$temp"
    done
}

while true; do
    current_data=$(curl -s "$data_endpoint")
    if [ -z "$current_data" ]; then
        echo "Failed to retrieve data. Retrying..."
        sleep "$poll_interval"
        continue
    fi

    if [[ "$current_data" != "$last_data" ]]; then
        echo "New block detected: $new_block"
        last_data="$current_data"
        current_miner_index=0
        shuffle_miners
    fi

    if ! pgrep -f "$process_name" > /dev/null; then
        if [ "$current_miner_index" -lt "${#miners[@]}" ]; then
            miner_address="${miners[$current_miner_index]}"
            block=$(echo "$current_data" | sed -n 's/.*"block":\([0-9]*\).*/\1/p')
            echo "Starting miner for $miner_address on block $block..."
            pkill -f "$process_name"
            bash "$mining_script" "$device" "$miner_address" "$message" &
            current_miner_index=$((current_miner_index + 1))
        fi
    else
        echo "Poller running with $process_name)..."
    fi
    sleep "$poll_interval"
done
