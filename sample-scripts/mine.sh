#!/bin/bash

# Endpoint for retrieving block data.
# e.g. returns {"hash":"AAAAA...HlP9Q=","block":768,"difficulty":8}
data_endpoint="http://localhost:3000/data"

# Endpoint for submitting block data.
# e.g. Expecting /submit?hash=AAAAA...HlP9Q=&nonce=789990&message=HI&address=G...`
submit_endpoint="http://localhost:3000/submit"

# Starting nonce.
nonce=0

# Message.
message="HI"

# Miner Stellar address (trustline to FCM required).
miner_address="GCWS2AKJCZ6U4YTTSXPHSYMR5EWXSKKVZSRV22NROAI7YRFJUZMBB3FN"

# Miner executable.
miner_cmd="../miner"

# GPU mode.
gpu=false

# Max threads or threads per block (GPU)
max_threads=10

# Batch size.
batch_size=5000000

# Verbose.
verbose=true

# Submission mode.
submission_mode="server"

# Fetch block data.
response=$(curl -s "$data_endpoint")
new_hash=$(echo "$response" | sed -n 's/.*"hash":"\([^"]*\)".*/\1/p')
new_block=$(echo "$response" | sed -n 's/.*"block":\([0-9]*\).*/\1/p')
new_difficulty=$(echo "$response" | sed -n 's/.*"difficulty":\([0-9]*\).*/\1/p')
new_block=$((new_block + 1))

# Run miner.
miner_command=("$miner_cmd" "$new_block" "$new_hash" "$nonce" "$new_difficulty" "$message" "$miner_address")
if $verbose; then
    miner_command+=("--verbose")
fi
miner_command+=("--max-threads" "$max_threads" "--batch-size" "$batch_size")
if $gpu; then
    miner_command+=("--gpu")
fi
echo "Running miner with hash=$new_hash, block=$new_block, difficulty=$new_difficulty, message=$message, address=$miner_address"
if $verbose; then
    output=$("${miner_command[@]}" | tee /dev/tty)
else
    output=$("${miner_command[@]}")
fi

# Retrieve hash and nonce.
mined_hash=$(echo "$output" | grep -oP '"hash": "\K[^"]+')
mined_nonce=$(echo "$output" | grep -oP '"nonce": \K\d+')
if [ -z "$mined_hash" ] || [ -z "$mined_nonce" ]; then
    exit 1
fi

# Submit to network.
if [ "$submission_mode" == "server" ]; then
    submit_url="${submit_endpoint}?hash=${mined_hash}&nonce=${mined_nonce}&message=${message}&address=${miner_address}"
    echo "Submitting: $submit_url"
    response=$(curl -s "$submit_url")
    echo "$response"
elif [ "$submission_mode" == "cli" ]; then
    PATH=$PATH:/root/.cargo/bin
    command="stellar contract invoke --id CC5TSJ3E26YUYGYQKOBNJQLPX4XMUHUY7Q26JX53CJ2YUIZB5HVXXRV6 \
        --source ADMIN --network MAINNET -- mine --hash $mined_hash --message \"$message\" --nonce $mined_nonce --miner \"$miner_address\""
    response=$(eval "$command")
    echo "$response"
else
    exit 1
fi