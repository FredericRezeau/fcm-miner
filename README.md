# fcm-miner

## C++ miner for [Stellar-Corium/FCM-sc](https://github.com/Stellar-Corium/FCM-sc)

`fcm-miner` is a standalone miner for the [FCM Smart Contract](https://github.com/Stellar-Corium/FCM-sc) on the Stellar blockchain. It supports parallel processing and custom batch size.

> **Note**: This project is experimental and was developed during my holiday, it may contain bugs. My main goal was to boost hashing speed on my available laptop and keep up with the increasing network hash rate and difficulty. Feel free to use, modify, or enhance it. I may also explore adding GPU support with OpenCL or CUDA in the future.

## Performance

Currently (only) tested on <> and **MS Surface Pro 9** with a **12th Gen Intel Core i7** processor (10 cores). The miner achieved an **average hash rate of 8.1 million hash/sec**.

I did not have time to test many C/C++ Keccak implementations, you may want to explore the other options here [keccak.team/software](https://keccak.team/software.html) for potential performance improvements (note that the standalone [XKCP implementation](https://github.com/XKCP/XKCP/blob/master/Standalone/CompactFIPS202/C/Keccak-more-compact.c) was much slower in my environment).


![screen](miner_10_30_2024.png)

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

## Disclaimer

This software is experimental and provided "as-is," without warranties or guarantees of any kind. Use it at your own risk. Please ensure you understand the risks mining on Stellar mainnet before deploying this software.

## License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.





