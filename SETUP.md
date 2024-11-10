# SETUP

## Sample scripts

The `sample-scripts` folder contains scripts from my current setup, shared here to help you set up your environment or serve as inspiration. They automate block monitoring, handle the miner process, and manage submissions to the Stellar network.

I run the poller on a separate machine to keep private keys off my machine (hence the `/submit` endpoint) but `mine.sh` can submit via the `Stellar CLI` directly if you set the `submission_mode="cli"`.

- `poller.js`: Node.js server to fetch, provide block data and *optionally* submit your transaction to the Stellar blockchain.
- `poll.sh`: Bash script to poll for block changes and the manage miner the instances.
- `mine.sh`: Bash script running the miner instance.
  
### Notes on FCM Protocol Update 0.1.0

The FCM protocol `0.1.0` (a.k.a. **After the Explosion**) introduces breaking changes for `fcm-miner` so running previous versions will likely cause issues and may incur extra fees for your miners!

#### Protocol Changes

The contract `mine` method now registers each valid call as an *attempt*, rather than considering it as final solution. Each miner address can make only one attempt per block, and a maximum of 255 attempts can be recorded per block. Difficulty is set by admin and currently sits at `6`.

Any `mine` call after 60 seconds from the last block triggers the resolution process:
- One winner is randomly chosen from up to 255 miners.
- Reward is calculated based on time elapsed since the last block (1 FCM per minute).

To leverage GPU mining, which can handle difficulty 6 almost instantly, the scripts have been updated to manage a list of miners instead of a single one. You can add as many miners as you want (see instructions below).

#### Important Considerations

Attempts are stored in temp storage, meaning attempt fees are much lower than a block fee. However, each miner you add will still incur a fee, and has a chance to be charged a full block fee.

You could modify your script to prevent attempts once the 60-second window has elapsed to avoid paying for block fee, or implement a clever strategy that adjusts based on your miners positions relative to the total miners on the block (e.g. it may be worth paying the block fee if you have 3/4 of the positions in this block). This exercise is left up to you, the current script will simply go through your miners list and submit one attempt per block for each.
  
### Spin up the server

Before starting, make sure the [Stellar CLI](https://developers.stellar.org/docs/build/smart-contracts/getting-started/setup) is installed if you plan to submit transactions via CLI on Server (default).

Configure your miners in poller.js

```js
const signers = {
    "G...KEY1": "SECRET...KEY1",
    "G...KEY2": "SECRET...KEY2"
    // Map more addresses in this list...
}
```

Then run the following to set up and start the server:

```bash
cd sample-scripts
npm install
PORT=3000 RPC_URL="https://your-rpc-url" npm start
```

### Configure the scripts

Edit the following variables in `poll.sh` to customize the setup for your environment:

```bash
data_endpoint="http://localhost:3000/data"
message="HELLO"
miners=(
    "GBGSMV..."
    "GASKJI..."
    "GBRLWH..."
    # add public addresses in this list...
)
```

Edit the following variables in `mine.sh` to customize the setup for your environment:

```bash
data_endpoint="http://localhost:3000/data"
submit_endpoint="http://localhost:3000/submit"
nonce=0
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

If you have multiple GPUs, you can run each of them in seperate terminals using `./poll.sh {n}`
