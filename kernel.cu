/*
    MIT License
    Author: Fred Kyung-jin Rezeau <fred@litemint.com>, 2024
    Permission is granted to use, copy, modify, and distribute this software for any purpose
    with or without fee.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
*/

#include <cuda_runtime.h>
#include <iostream>
#include <cstdint>
#include <cstring>
#include <cstddef>

#include "utils/keccak.cuh"

constexpr int maxDataSize = 256;
__constant__ std::uint8_t deviceData[maxDataSize];

#define CUDA_CALL(call)                                                \
    do {                                                               \
        cudaError_t err = call;                                        \
        if (err != cudaSuccess) {                                      \
            fprintf(stderr, "CUDA Error in %s, line %d: %s\n",         \
                    __FILE__, __LINE__, cudaGetErrorString(err));      \
            exit(EXIT_FAILURE);                                        \
        }                                                              \
    } while (0)

__device__ __forceinline__ void updateNonce(std::uint64_t val, std::uint8_t* buffer) {
    // Xdr bytes first.
    buffer[0] = 0;
    buffer[1] = 0;
    buffer[2] = 0;
    buffer[3] = 5;
    #pragma unroll 12
    for (int i = 4; i < 12; i++) {
        buffer[11 - (i - 4)] = static_cast<std::uint8_t>(val & 0xFF);
        val >>= 8;
    }
}

__device__ __forceinline__ bool check(const std::uint8_t* hash, int difficulty) {
    int zeros = 0;
    #pragma unroll 32
    for (int i = 0; i < 32; ++i) {
        int zero = -(hash[i] == 0);
        zeros += (zero & 2) | (~zero & ((-((hash[i] >> 4) == 0)) & 1));
        i += ((hash[i] != 0) | (zeros >= difficulty)) * (32 - i);
    }
    return zeros == difficulty;
}

__device__ __forceinline__ void vCopy(std::uint8_t* dest, const std::uint8_t* src, int size) {
    // Align then copy 8 bytes at a time, more efficient than memcpy.
    int i = 0;
    while (i < size && ((uintptr_t)(dest + i) % 8 != 0)) {
        dest[i] = src[i];
        i++;
    }
    #pragma unroll
    for (; i + 7 < size; i += 8) {
        *(reinterpret_cast<std::uint64_t*>(dest + i)) = *(reinterpret_cast<const std::uint64_t*>(src + i));
    }
    #pragma unroll
    for (; i < size; ++i) {
        dest[i] = src[i];
    }
}

__global__ void run(int dataSize, std::uint64_t startNonce, int nonceOffset, std::uint64_t batchSize, int difficulty,
                                 int* __restrict__ found, std::uint8_t* __restrict__ output, std::uint64_t* __restrict__ validNonce) {
    std::uint64_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    std::uint64_t stride = gridDim.x * blockDim.x;
    if (idx >= batchSize || atomicAdd(found, 0) == 1)
        return;
    std::uint64_t nonceEnd = startNonce + batchSize;

    // Nonce distribution is based on thread id - spaced by stride.
    for (std::uint64_t nonce = startNonce + idx; nonce < nonceEnd; nonce += stride) {
        std::uint8_t threadData[maxDataSize];
        if (dataSize > maxDataSize)
            return;
        vCopy(threadData, deviceData, dataSize);
        updateNonce(nonce, &threadData[nonceOffset]);
        std::uint8_t hash[32];
        keccak256(threadData, dataSize, hash);
        if (check(hash, difficulty)) {
            if (atomicCAS(found, 0, 1) == 0) {
                memcpy(output, hash, 32);
                atomicExch(reinterpret_cast<unsigned long long int*>(validNonce), nonce);
            }
            return;
        }
        if (atomicAdd(found, 0) == 1)
            return;
    }
}

extern "C" int executeKernel(std::uint8_t* data, int dataSize, std::uint64_t startNonce, int nonceOffset, std::uint64_t batchSize,
    int difficulty, int threadsPerBlock, std::uint8_t* output, std::uint64_t* validNonce) {
    std::uint8_t* deviceOutput;
    std::size_t outputSize = 32 * sizeof(std::uint8_t);
    int found = 0;
    int* deviceFound;
    std::uint64_t* deviceNonce;
    cudaDeviceProp deviceProp;
    CUDA_CALL(cudaGetDeviceProperties(&deviceProp, 0));
    CUDA_CALL(cudaMalloc((void**)&deviceFound, sizeof(int)));
    CUDA_CALL(cudaMemcpy(deviceFound, &found, sizeof(int), cudaMemcpyHostToDevice));
    CUDA_CALL(cudaMemcpyToSymbol(deviceData, data, dataSize));
    CUDA_CALL(cudaMalloc((void**)&deviceOutput, outputSize));
    CUDA_CALL(cudaMalloc((void**)&deviceNonce, sizeof(std::uint64_t)));
    CUDA_CALL(cudaMemset(deviceNonce, 0, sizeof(std::uint64_t)));

    int threads = threadsPerBlock;
    std::uint64_t blocks = (batchSize + threads - 1) / threads;
    if (blocks > deviceProp.maxGridSize[0]) {
        blocks = deviceProp.maxGridSize[0];
    }
    std::uint64_t adjustedBatchSize = blocks * threads;
    run<<<(unsigned int)blocks, threads>>>(dataSize, startNonce,
        nonceOffset, adjustedBatchSize, difficulty, deviceFound, deviceOutput, deviceNonce);
    CUDA_CALL(cudaDeviceSynchronize());
    CUDA_CALL(cudaMemcpy(output, deviceOutput, outputSize, cudaMemcpyDeviceToHost));
    CUDA_CALL(cudaMemcpy(&found, deviceFound, sizeof(int), cudaMemcpyDeviceToHost));
    CUDA_CALL(cudaMemcpy(validNonce, deviceNonce, sizeof(std::uint64_t), cudaMemcpyDeviceToHost));
    CUDA_CALL(cudaFree(deviceOutput));
    CUDA_CALL(cudaFree(deviceFound));
    CUDA_CALL(cudaFree(deviceNonce));
    return found;
}
