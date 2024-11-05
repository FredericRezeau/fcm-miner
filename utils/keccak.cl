// MIT License

// Keccak256 standalone CUDA implementation based on the NIST standard:
// Reference: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf

// Additional C/C++ implementations for Keccak can be found here:
// https://keccak.team/software.html

// Note: The standalone XKCP implementation performed slower in my environment.
// (use `FIPS202_SHA3_256` but replace the padding parameter 0x06 with 0x01)
// https://github.com/XKCP/XKCP/blob/master/Standalone/CompactFIPS202/C/Keccak-more-compact.c

typedef struct {
    uchar state[200];
    size_t offset;
} Keccak256Context;

__constant ulong roundConstants[24] = {
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

__constant int rhoOffsets[24] = {
    1, 3, 6, 10, 15, 21, 28, 36,
    45, 55, 2, 14, 27, 41, 56,
    8, 25, 43, 62, 18, 39, 61,
    20, 44
};

__constant int piIndexes[24] = {
    10, 7, 11, 17, 18, 3, 5, 16,
    8, 21, 24, 4, 15, 23, 19, 13,
    12, 2, 20, 14, 22, 9, 6, 1
};

inline ulong rotl64(ulong x, uint n) {
    return (x << n) | (x >> (64 - n));
}

void keccakF1600(uchar* state) {
    ulong state64[25];
    for (int i = 0; i < 25; ++i) {
        state64[i] = 0;
        for (int j = 0; j < 8; ++j) {
            state64[i] |= ((ulong)state[i * 8 + j]) << (8 * j);
        }
    }

    for (int round = 0; round < 24; ++round) {
        ulong C[5], D[5];
        for (int x = 0; x < 5; ++x)
            C[x] = state64[x] ^ state64[x + 5] ^ state64[x + 10] ^ state64[x + 15] ^ state64[x + 20];

        for (int x = 0; x < 5; ++x) {
            D[x] = C[(x + 4) % 5] ^ rotl64(C[(x + 1) % 5], 1);
            for (int y = 0; y < 25; y += 5)
                state64[y + x] ^= D[x];
        }

        ulong temp = state64[1];
        for (int i = 0; i < 24; ++i) {
            int index = piIndexes[i];
            ulong t = state64[index];
            state64[index] = rotl64(temp, rhoOffsets[i]);
            temp = t;
        }

        for (int y = 0; y < 25; y += 5) {
            ulong tempVars[5];
            for (int x = 0; x < 5; ++x)
                tempVars[x] = state64[y + x];
            for (int x = 0; x < 5; ++x)
                state64[y + x] = tempVars[x] ^ ((~tempVars[(x + 1) % 5]) & tempVars[(x + 2) % 5]);
        }

        state64[0] ^= roundConstants[round];
    }

    for (int i = 0; i < 25; ++i) {
        for (int j = 0; j < 8; ++j) {
            state[i * 8 + j] = (uchar)((state64[i] >> (8 * j)) & 0xFF);
        }
    }
}

inline void keccak256Reset(Keccak256Context* ctx) {
    for (int i = 0; i < 200; ++i) {
        ctx->state[i] = 0;
    }
    ctx->offset = 0;
}

inline void keccak256Update(Keccak256Context* ctx, const uchar* data, size_t len) {
    size_t rate = 136;
    while (len > 0) {
        size_t chunk = (len < rate - ctx->offset) ? len : rate - ctx->offset;
        for (size_t i = 0; i < chunk; ++i) {
            ctx->state[ctx->offset + i] ^= data[i];
        }
        ctx->offset += chunk;
        data += chunk;
        len -= chunk;
        if (ctx->offset == rate) {
            keccakF1600(ctx->state);
            ctx->offset = 0;
        }
    }
}

inline void keccak256Finalize(Keccak256Context* ctx, uchar* hash) {
    size_t rate = 136;
    ctx->state[ctx->offset] ^= 0x01;
    ctx->state[rate - 1] ^= 0x80;
    keccakF1600(ctx->state);
    for (int i = 0; i < 32; ++i) {
        hash[i] = ctx->state[i];
    }
}

inline void keccak256(const uchar* input, size_t size, uchar* output) {
    Keccak256Context ctx;
    keccak256Reset(&ctx);
    keccak256Update(&ctx, input, size);
    keccak256Finalize(&ctx, output);
}