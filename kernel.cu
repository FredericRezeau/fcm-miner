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

#define CUDA_CALL(call)                                                \
    do {                                                               \
        cudaError_t err = call;                                        \
        if (err != cudaSuccess) {                                      \
            fprintf(stderr, "CUDA Error in %s, line %d: %s\n",         \
                    __FILE__, __LINE__, cudaGetErrorString(err));      \
            exit(EXIT_FAILURE);                                        \
        }                                                              \
    } while (0)

__device__ void updateNonce(std::uint64_t val, std::uint8_t* buffer) {
    // Xdr bytes first.
    buffer[0] = 0;
    buffer[1] = 0;
    buffer[2] = 0;
    buffer[3] = 5;
    for (int i = 4; i < 12; i++) {
        buffer[11 - (i - 4)] = static_cast<std::uint8_t>(val & 0xFF);
        val >>= 8;
    }
}

__device__ bool check(const std::uint8_t* hash, int difficulty) {
    int zeros = 0;
    for (int i = 0; i < 32; ++i) {
        zeros += (hash[i] == 0) ? 2 : ((hash[i] >> 4) == 0 ? 1 : 0);
        if (hash[i] != 0 || zeros >= difficulty)
            break;
    }
    return zeros >= difficulty;
}

__global__ void run(std::uint8_t* data, int dataSize, std::uint64_t startNonce,
                                 int nonceOffset, std::uint64_t batchSize, int difficulty,
                                 int* found, std::uint8_t* output, std::uint64_t* validNonce) {
    std::uint64_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    std::uint64_t stride = gridDim.x * blockDim.x;
    if (idx >= batchSize || atomicAdd(found, 0) == 1)
        return;
    std::uint64_t nonceEnd = startNonce + batchSize;
    const int maxSize = 256;

    // Nonce distribution is based on thread id - spaced by stride.
    for (std::uint64_t nonce = startNonce + idx; nonce < nonceEnd; nonce += stride) {
        std::uint8_t threadData[maxSize];
        if (dataSize > maxSize)
            return;
        for (int i = 0; i < dataSize; i++) {
            threadData[i] = data[i];
        }
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
    std::uint8_t* deviceData;
    std::uint8_t* deviceOutput;
    std::size_t outputSize = 32 * sizeof(std::uint8_t);
    int found = 0;
    int* deviceFound;
    std::uint64_t* deviceNonce;
    cudaDeviceProp deviceProp;
    CUDA_CALL(cudaGetDeviceProperties(&deviceProp, 0));
    CUDA_CALL(cudaMalloc((void**)&deviceFound, sizeof(int)));
    CUDA_CALL(cudaMemcpy(deviceFound, &found, sizeof(int), cudaMemcpyHostToDevice));
    CUDA_CALL(cudaMalloc((void**)&deviceData, dataSize));
    CUDA_CALL(cudaMalloc((void**)&deviceOutput, outputSize));
    CUDA_CALL(cudaMalloc((void**)&deviceNonce, sizeof(std::uint64_t)));
    CUDA_CALL(cudaMemset(deviceNonce, 0, sizeof(std::uint64_t)));
    CUDA_CALL(cudaMemcpy(deviceData, data, dataSize, cudaMemcpyHostToDevice));

    int threads = threadsPerBlock;
    std::uint64_t blocks = (batchSize + threads - 1) / threads;
    if (blocks > deviceProp.maxGridSize[0]) {
        blocks = deviceProp.maxGridSize[0];
    }
    std::uint64_t adjustedBatchSize = blocks * threads;
    run<<<(unsigned int)blocks, threads>>>(deviceData, dataSize, startNonce,
        nonceOffset, adjustedBatchSize, difficulty, deviceFound, deviceOutput, deviceNonce);
    CUDA_CALL(cudaDeviceSynchronize());
    CUDA_CALL(cudaMemcpy(output, deviceOutput, outputSize, cudaMemcpyDeviceToHost));
    CUDA_CALL(cudaMemcpy(&found, deviceFound, sizeof(int), cudaMemcpyDeviceToHost));
    CUDA_CALL(cudaMemcpy(validNonce, deviceNonce, sizeof(std::uint64_t), cudaMemcpyDeviceToHost));
    CUDA_CALL(cudaFree(deviceData));
    CUDA_CALL(cudaFree(deviceOutput));
    CUDA_CALL(cudaFree(deviceFound));
    CUDA_CALL(cudaFree(deviceNonce));
    return found;
}
