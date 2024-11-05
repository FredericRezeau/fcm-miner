# SETUP

## Sample scripts

The `sample-scripts` folder contains scripts from my current setup, shared here to help you set up your environment or serve as inspiration. They automate block monitoring, handle the miner process, and manage submissions to the Stellar network.

I run the poller on a separate machine to keep private keys off my machine (hence the `/submit` endpoint) but `mine.sh` can submit via the `Stellar CLI` directly if you set the `submission_mode="cli"`.

- `poller.js`: Node.js server to fetch, provide block data and *optionally* submit your transaction to the Stellar blockchain.
- `poll.sh`: Bash script to poll for block changes and the manage miner the instances.
- `mine.sh`: Bash script running the miner instance.
  
### Spin up the server

Before starting, make sure the [Stellar CLI](https://developers.stellar.org/docs/build/smart-contracts/getting-started/setup) is installed if you plan to submit transactions via CLI on Server (default). Alternatively you can set the `signer` secret key in `poller.js` so it will not require the CLI.

Then run the following to set up and start the server:

```bash
cd sample-scripts
npm install
PORT=3000 RPC_URL="https://your-rpc-url" npm start
```

### Configure the scripts

Edit the following variable in `poll.sh` to customize the setup for your environment:

```bash
data_endpoint="http://localhost:3000/data"
```

Edit the following variables in `mine.sh` to customize the setup for your environment:

```bash
data_endpoint="http://localhost:3000/data"
submit_endpoint="http://localhost:3000/submit"
nonce=0
message="HI"
miner_address="GCWS2...BB3FN"
max_threads=10
batch_size=5000000
verbose=true
gpu=false
```

#### Some notes on `max_threads` and `batch_size`

- For CPU mining, `max_threads` should be set within the range of your available CPU cores.
- For GPU mining, `max_threads` refers to the number of threads per block. It should be a multiple of the warp size (32) so using 256, 512, 768 is generally recommended.
- The `batch_size` parameter determines the number of hashes processed in a single batch. Should be set based on your CPU or GPU performance, balance to minimize overhead and maximizing throughput.

### Start mining

To begin mining, run the poller script with:

```bash
cd sample-scripts
./poll.sh
```