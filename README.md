# fcm-miner

## C++ miner for [Stellar-Corium/FCM-sc](https://github.com/Stellar-Corium/FCM-sc)

`fcm-miner` is a standalone miner for the [FCM Smart Contract](https://github.com/Stellar-Corium/FCM-sc) on the Stellar blockchain. It supports **CPU parallel processing**, and optional **GPU acceleration with both CUDA and OpenCL**.

> **Note**: This project is experimental and was developed during my holiday, it may contain bugs. My main goal was to boost hashing speed on my available laptop and keep up with the increasing network hash rate and difficulty. Feel free to use, modify, or enhance it. I have now added GPU support with **CUDA** and **OpenCL** - should help to support a wider range of hardware.

## Performance

### CPU Performance

Initially tested on **MS Surface Pro 9** with a **12th Gen Intel Core i7** processor (10 cores). The miner achieved an **average hash rate of 8.1 MH/s**.

### GPU Performance

With GPU acceleration enabled on an **NVIDIA GeForce RTX 4080** GPU, the miner achieved an average hash rate of **1.6 GH/s** (CUDA). The OpenCL implementation is about 18% slower. There is still room for improving the kernel code in both!

| GPU           | Framework | Avg. Hash Rate |
|---------------------|-----------|-------------------|
| NVIDIA GeForce RTX 4080 | CUDA      | ~1.6 GH/s     |
| NVIDIA GeForce RTX 4080 | OpenCL    | ~1.3 GH/s     |

### Keccak Hashing

I did not have time to test many C/C++ Keccak implementations, you may want to explore the other options here [keccak.team/software](https://keccak.team/software.html) for potential performance improvements (note that the standalone [XKCP implementation](https://github.com/XKCP/XKCP/blob/master/Standalone/CompactFIPS202/C/Keccak-more-compact.c) was much slower in my environment).

## Requirements

- **C++17** or higher
- **C++ Standard Library** (no additional dependencies required)
  
### GPU Build (CUDA)

- **NVIDIA CUDA-Capable GPU** with compute capability 3.0 or higher
- [**NVIDIA CUDA Toolkit**](https://developer.nvidia.com/cuda-toolkit)

### GPU Build (OpenCL)

- **OpenCL 3.0** or higher
- **OpenCL SDK**
  - for NVIDIA: [NVIDIA CUDA Toolkit (includes OpenCL)](https://developer.nvidia.com/cuda-toolkit)
  - for AMD: [AMD SDK (supports OpenCL)](https://developer.amd.com/tools-and-sdks/)
  - for Intel: [Intel SDK for OpenCL](http://software.intel.com/en-us/vcsource/tools/opencl-sdk)

## Compilation

### CPU-Only Compilation

To compile the miner without GPU support, simply run:

```bash
make clean
make
```
> Note: You may need to modify `CXXFLAGS` based on your environment or to fine-tune performance.

### GPU-Enabled Compilation

To compile the miner with GPU support, run:

CUDA:

```bash
make clean
make GPU=CUDA
```
or OpenCL:
```bash
make clean
make GPU=OPENCL
```
Note: The current OpenCL implementation uses the `cl_khr_int64_base_atomics` extension for atomic operations on 64-bit integers. Make sure your device supports it.

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
| `[--max-threads <num>]`  | Specifies the maximum number of threads (CPU) or threads per block (GPU).              | 4                |
| `[--batch-size <size>]`  | Number of hash attempts per batch.                           | 10000000         |
| `[--gpu]`  | Enable GPU mining                           | Disabled          |
| `[--device]`  | Specify the device id                           | 0          |

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

IMPORTANT: When using `--gpu`, the `--max-threads` parameter specifies the number of threads per block (e.g. 512, 768), and --batch-size should be adjusted based on your GPU capabilities.

## Getting Started

The `sample-scripts` folder contains scripts from my current setup, shared here to help you set up your environment or serve as inspiration.

Check [SETUP](https://github.com/FredericRezeau/fcm-miner/blob/main/SETUP.md) for more details on how to use them.


## Disclaimer

This software is experimental and provided "as-is," without warranties or guarantees of any kind. Use it at your own risk. Please ensure you understand the risks mining on Stellar mainnet before deploying this software.

## License

[MIT License](LICENSE)



