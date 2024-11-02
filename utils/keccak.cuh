#pragma once

// MIT License

// Keccak256 standalone CUDA implementation based on the NIST standard:
// Reference: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf

// Additional C/C++ implementations for Keccak can be found here:
// https://keccak.team/software.html

// Note: The standalone XKCP implementation performed slower in my environment.
// (use `FIPS202_SHA3_256` but replace the padding parameter 0x06 with 0x01)
// https://github.com/XKCP/XKCP/blob/master/Standalone/CompactFIPS202/C/Keccak-more-compact.c

#include <cuda_runtime.h>
#include <cstdint>

struct Keccak256Context {
    std::uint8_t state[200];
    std::size_t offset;
};

__device__ const std::uint64_t roundConstants[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL,
    0x800000000000808aULL, 0x8000000080008000ULL,
    0x000000000000808bULL, 0x0000000080000001ULL,
    0x8000000080008081ULL, 0x8000000000008009ULL,
    0x000000000000008aULL, 0x0000000000000088ULL,
    0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL,
    0x8000000000008089ULL, 0x8000000000008003ULL,
    0x8000000000008002ULL, 0x8000000000000080ULL,
    0x000000000000800aULL, 0x800000008000000aULL,
    0x8000000080008081ULL, 0x8000000000008080ULL,
    0x0000000080000001ULL, 0x8000000080008008ULL
};

__device__ const int rhoOffsets[24] = {
    1, 3, 6, 10, 15, 21, 28, 36,
    45, 55, 2, 14, 27, 41, 56,
    8, 25, 43, 62, 18, 39, 61,
    20, 44
};

__device__ const int piIndexes[24] = {
    10, 7, 11, 17, 18, 3, 5, 16,
    8, 21, 24, 4, 15, 23, 19, 13,
    12, 2, 20, 14, 22, 9, 6, 1
};

__device__ __forceinline__ std::uint64_t rotl64(std::uint64_t x, std::uint64_t n) {
    return (x << n) | (x >> (64 - n));
}

__device__ void keccakF1600(std::uint8_t* state) {
    std::uint64_t* state64 = reinterpret_cast<std::uint64_t*>(state);
    for (int round = 0; round < 24; ++round) {
        std::uint64_t C[5], D[5];
        for (int x = 0; x < 5; ++x)
            C[x] = state64[x] ^ state64[x + 5] ^ state64[x + 10] ^ state64[x + 15] ^ state64[x + 20];
        for (int x = 0; x < 5; ++x) {
            D[x] = C[(x + 4) % 5] ^ rotl64(C[(x + 1) % 5], 1);
            for (int y = 0; y < 25; y += 5)
                state64[y + x] ^= D[x];
        }
        std::uint64_t temp = state64[1];
        for (int i = 0; i < 24; ++i) {
            int index = piIndexes[i];
            std::uint64_t t = state64[index];
            state64[index] = rotl64(temp, rhoOffsets[i]);
            temp = t;
        }
        for (int y = 0; y < 25; y += 5) {
            std::uint64_t tempVars[5];
            for (int x = 0; x < 5; ++x)
                tempVars[x] = state64[y + x];
            for (int x = 0; x < 5; ++x)
                state64[y + x] = tempVars[x] ^ ((~tempVars[(x + 1) % 5]) & tempVars[(x + 2) % 5]);
        }
        state64[0] ^= roundConstants[round];
    }
}

__device__ void keccak256Reset(Keccak256Context* ctx) {
    for (int i = 0; i < 200; ++i)
        ctx->state[i] = 0;
    ctx->offset = 0;
}

__device__ void keccak256Update(Keccak256Context* ctx, const std::uint8_t* data, std::size_t len) {
    std::size_t rate = 136;
    while (len > 0) {
        std::size_t chunk = (len < rate - ctx->offset) ? len : rate - ctx->offset;
        for (std::size_t i = 0; i < chunk; ++i)
            ctx->state[ctx->offset + i] ^= data[i];
        ctx->offset += chunk;
        data += chunk;
        len -= chunk;
        if (ctx->offset == rate) {
            keccakF1600(ctx->state);
            ctx->offset = 0;
        }
    }
}

__device__ void keccak256Finalize(Keccak256Context* ctx, std::uint8_t* hash) {
    std::size_t rate = 136;
    ctx->state[ctx->offset] ^= 0x01;
    ctx->state[rate - 1] ^= 0x80;
    keccakF1600(ctx->state);
    for (int i = 0; i < 32; ++i) {
        hash[i] = ctx->state[i];
    }
}

__device__ void keccak256(const std::uint8_t* input, std::size_t size, std::uint8_t* output) {
    Keccak256Context ctx;
    keccak256Reset(&ctx);
    keccak256Update(&ctx, input, size);
    keccak256Finalize(&ctx, output);
}