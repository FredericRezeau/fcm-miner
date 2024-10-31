#!/bin/bash

data_endpoint="http://localhost:3000/data"
mining_script="./mine.sh"
poll_interval=2
last_data=""

while true; do
    current_data=$(curl -s "$data_endpoint")
    if [ -z "$current_data" ]; then
        echo "Failed to retrieve data. Retrying..."
        sleep "$poll_interval"
        continue
    fi

    if ! pgrep -f "./miner" > /dev/null || [[ "$current_data" != "$last_data" ]]; then
        last_data="$current_data"
        echo "Restarting miner..."
        pkill -f "./miner"
        bash "$mining_script" &
    else
        echo "Poller running..."
    fi
    sleep "$poll_interval"
done
