# fcm-miner

## C++ miner for [Stellar-Corium/FCM-sc](https://github.com/Stellar-Corium/FCM-sc)

`fcm-miner` is a standalone miner for the [FCM Smart Contract](https://github.com/Stellar-Corium/FCM-sc) on the Stellar blockchain. It supports parallel processing and custom batch size.

> **Note**: This project is experimental and was developed during my holiday, it may contain bugs. My main goal was to boost hashing speed on my available laptop and keep up with the increasing network hash rate and difficulty. Feel free to use, modify, or enhance it. I may also explore adding GPU support with OpenCL or CUDA in the future.

## Performance

Currently (only) tested on **MS Surface Pro 9** with a **12th Gen Intel Core i7** processor (10 cores). The miner achieved an **average hash rate of 8.1 million hash/sec**.

I did not have time to test many C/C++ Keccak implementations, you may want to explore the other options here [keccak.team/software](https://keccak.team/software.html) for potential performance improvements (note that the standalone [XKCP implementation](https://github.com/XKCP/XKCP/blob/master/Standalone/CompactFIPS202/C/Keccak-more-compact.c) was much slower in my environment).


![screen](https://github.com/FredericRezeau/fcm-miner/blob/main/miner%2010_30_2024.png)

## Requirements

- **C++17** or higher
- **C++ Standard Library** (no additional dependencies required)

## Compilation

To compile the miner, simply run:

```bash
make
```
You may need to modify `CXXFLAGS` based on your environment or to fine-tune performance.

## Usage

```bash
./miner <block> <hash> <nonce> <difficulty> <message> <miner_address> [--verbose] [--max-threads <num> (default 4)] [--batch-size <size> (default 10000000)]
```

### Parameters

| Parameter              | Description                                                    | Default Value     |
|------------------------|----------------------------------------------------------------|-------------------|
| `<block>`              | The block number being mined. Last found block + 1.            | _(Required)_      |
| `<hash>`               | Previous hash value (base64 encoded).                                  | _(Required)_      |
| `<nonce>`              | Starting nonce value.                                          | _(Required)_      |
| `<difficulty>`         | The mining difficulty level.                                   | _(Required)_      |
| `<message>`            | Message to include in the block.                               | _(Required)_      |
| `<miner_address>`      | `G` address for reward distribution. Must have FCM trustline.  | _(Required)_      |
| `[--verbose]`            | Verbose mode incl. hash rate monitoring                      | Disabled          |
| `[--max-threads <num>]`  | Specifies the maximum number of threads to use.              | 4                 |
| `[--batch-size <size>]`  | Number of hash attempts per batch.                           | 10000000          |

Example:
```bash
./miner 634 AAAAAM9LXIBl6/ByQIFVmjn977O/5LeR8VrUZ4GEEFs= 72651349000 9 HI GCWS2AKJCZ6U4YTTSXPHSYMR5EWXSKKVZSRV22NROAI7YRFJUZMBB3FN --max-threads 10 --batch-size 20000000 --verbose
```

Output:
```json
{
 "hash": "0000000004166398a1c7e245335fc382e639bd8d82a08c376b5fa41a05dab522",
  "nonce": 72651349019
}
```

## Sample scripts

These scripts are part of my current setup and shared here to help setup your environment. They automate block monitoring, handle the miner process, and manage submissions to the Stellar network.

I run the poller on a separate machine to keep private keys off my machine (hence the `/submit` endpoint) but `mine.sh` could also be modified to submit via `Stellar CLI` directly if you run everything locally.

- `poller.js`: Node.js server to fetch, provide block data and submit your transaction to the Stellar blockchain.
- `poll.sh`: Bash script to poll for block changes and manage mining instance
- `mine.sh`: Bash script to instantiate the mining process.
  
### Spin up the server

Before starting, make sure the [Stellar CLI](https://developers.stellar.org/docs/build/smart-contracts/getting-started/setup) is installed if you plan to submit transactions directly via this setup.

Run the following to set up and start the server:

```bash
cd sample-scripts
npm install
PORT=3000 RPC_URL="https://your-rpc-url" npm start
```

### Configure the scripts

Edit the following variables in `poller.sh` and `mine.sh` to customize the setup for your environment:

```bash
data_endpoint="http://localhost:3000/data"
submit_endpoint="http://localhost:3000/submit"
nonce=0
message="HI"
miner_address="GCWS2...BB3FN"
max_threads=10
batch_size=5000000
verbose=true
```

### Start mining

To begin mining, run the poller script with:

```bash
cd sample-scripts
./poll.sh
```

## Disclaimer

This software is experimental and provided "as-is," without warranties or guarantees of any kind. Use it at your own risk. Please ensure you understand the risks mining on Stellar mainnet before deploying this software.

## License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.





