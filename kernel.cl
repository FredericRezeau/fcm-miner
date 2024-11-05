/* 
    MIT License
    Author: Fred Kyung-jin Rezeau <fred@litemint.com>, 2024
    Permission is granted to use, copy, modify, and distribute this software for any purpose
    with or without fee.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
*/

#pragma OPENCL EXTENSION cl_khr_int64_base_atomics : enable

#define maxDataSize 256

void keccak256(const uchar* input, size_t size, uchar* output);  // See utils/keccak.cl (concatenated at runtime).

inline void updateNonce(ulong val, uchar* buffer) {
    // XDR bytes first.
    buffer[0] = 0;
    buffer[1] = 0;
    buffer[2] = 0;
    buffer[3] = 5;
    for (int i = 4; i < 12; i++) {
        buffer[11 - (i - 4)] = (uchar)(val & 0xFF);
        val >>= 8;
    }
}

inline int check(const uchar* hash, int difficulty) {
    int zeros = 0;
    for (int i = 0; i < 32; ++i) {
        // Optimized difficulty check by avoiding branching.
        int zero = -(hash[i] == 0);
        zeros += (zero & 2) | (~zero & ((-((hash[i] >> 4) == 0)) & 1));
        i += ((hash[i] != 0 || zeros >= difficulty) ? (32 - i) : 0);
    }
    return zeros == difficulty;
}

inline void copy(uchar* dest, const __global uchar* src, int size) {
    for (int i = 0; i < size; ++i) {
        dest[i] = src[i]; // TODO: optimize with vectorized copy.
    }
}

__kernel void run(int dataSize, ulong startNonce, int nonceOffset, ulong batchSize, int difficulty,
    __global const uchar* deviceData, __global atomic_int* found, __global uchar* output, __global ulong* validNonce
) {
    ulong idx = get_global_id(0);
    ulong stride = get_global_size(0);
    if (idx >= batchSize || atomic_load(found) == 1)
        return;

    ulong nonceEnd = startNonce + batchSize;

    // Nonce distribution is based on thread id - spaced by stride.
    for (ulong nonce = startNonce + idx; nonce < nonceEnd; nonce += stride) {
        uchar threadData[maxDataSize];
        if (dataSize > maxDataSize)
            return;
        copy(threadData, deviceData, dataSize);
        updateNonce(nonce, &threadData[nonceOffset]);
        uchar hash[32];
        keccak256(threadData, dataSize, hash);
        if (check(hash, difficulty)) {
            if (atomic_cmpxchg((volatile __global int*)found, 0, 1) == 0) {
                for (int i = 0; i < 32; ++i) {
                    output[i] = hash[i];
                }
                *validNonce = nonce;
            }
            return;
        }
        if (atomic_load(found) == 1)
            return;
    }
}
