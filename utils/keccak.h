#pragma once

// MIT License

// Keccak256 standalone implementation based on the NIST standard:
// Reference: https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.202.pdf

// Additional C/C++ implementations for Keccak can be found here:
// https://keccak.team/software.html

// Note: The standalone XKCP implementation performed slower in my environment.
// (use `FIPS202_SHA3_256` but replace the padding parameter 0x06 with 0x01)
// https://github.com/XKCP/XKCP/blob/master/Standalone/CompactFIPS202/C/Keccak-more-compact.c

#include <cstdint>
#include <cstring>

class Keccak256 {
public:
    Keccak256() { reset(); }

    void update(const uint8_t* data, size_t len) {
        while (len > 0) {
            size_t chunk = (len < rate - offset) ? len : rate - offset;
            for (size_t i = 0; i < chunk; ++i)
                state[offset + i] ^= data[i];
            offset += chunk;
            data += chunk;
            len -= chunk;
            if (offset == rate) {
                keccakF1600(state);
                offset = 0;
            }
        }
    }

    void finalize(uint8_t* hash) {
        state[offset] ^= 0x01;
        state[rate - 1] ^= 0x80;
        keccakF1600(state);
        std::memcpy(hash, state, 32);
    }

    void reset() {
        std::memset(state, 0, sizeof(state));
        offset = 0;
    }

    int runTests() {
        std::vector<std::pair<std::vector<uint8_t>, std::vector<uint8_t>>> testCases = {
            {
                {},
                {0xc5, 0xd2, 0x46, 0x01, 0x86, 0xf7, 0x23, 0x3c, 0x92, 0x7e, 0x7d, 0xb2, 0xdc, 0xc7, 0x03, 0xc0,
                0xe5, 0x00, 0xb6, 0x53, 0xca, 0x82, 0x27, 0x3b, 0x7b, 0xfa, 0xd8, 0x04, 0x5d, 0x85, 0xa4, 0x70}
            },
            {
                {'a', 'b', 'c'},
                {0x4e, 0x03, 0x65, 0x7a, 0xea, 0x45, 0xa9, 0x4f, 0xc7, 0xd4, 0x7b, 0xa8, 0x26, 0xc8, 0xd6, 0x67,
                0xc0, 0xd1, 0xe6, 0xe3, 0x3a, 0x64, 0xa0, 0x36, 0xec, 0x44, 0xf5, 0x8f, 0xa1, 0x2d, 0x6c, 0x45}
            }
        };
        bool allPassed = true;
        for (const auto& [message, expectedHash] : testCases) {
            allPassed &= runTest(message, expectedHash);
        }
        if (allPassed) {
            std::cout << "Passed." << std::endl;
        } else {
            std::cout << "Failed." << std::endl;
        }
        return allPassed ? 0 : 1;
    }

private:
    static constexpr size_t rate = 136;
    static constexpr size_t capacity = 64;
    static constexpr size_t stateSize = (rate + capacity) / 8;
    uint8_t state[200] = {};
    size_t offset = 0;

    static void keccakF1600(uint8_t* state) {
        static constexpr uint64_t roundConstants[24] = {
            0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL, 0x8000000080008000ULL,
            0x000000000000808bULL, 0x0000000080000001ULL, 0x8000000080008081ULL, 0x8000000000008009ULL,
            0x000000000000008aULL, 0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
            0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL, 0x8000000000008003ULL,
            0x8000000000008002ULL, 0x8000000000000080ULL, 0x000000000000800aULL, 0x800000008000000aULL,
            0x8000000080008081ULL, 0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL
        };

        uint64_t* state64 = reinterpret_cast<uint64_t*>(state);
        for (uint64_t roundConstant : roundConstants) {
            uint64_t C[5], D, temp;
            for (size_t x = 0; x < 5; ++x)
                C[x] = state64[x] ^ state64[x + 5] ^ state64[x + 10] ^ state64[x + 15] ^ state64[x + 20];

            for (size_t x = 0; x < 5; ++x) {
                D = C[(x + 4) % 5] ^ rotl64(C[(x + 1) % 5], 1);
                for (size_t y = 0; y < 25; y += 5)
                    state64[x + y] ^= D;
            }

            temp = state64[1];
            for (size_t i = 0; i < 24; ++i) {
                size_t j = rhoOffsets[i];
                uint64_t t = state64[piIndexes[i]];
                state64[piIndexes[i]] = rotl64(temp, j);
                temp = t;
            }

            for (size_t y = 0; y < 25; y += 5) {
                uint64_t temp[5];
                for (size_t x = 0; x < 5; ++x)
                    temp[x] = state64[y + x];
                for (size_t x = 0; x < 5; ++x)
                    state64[y + x] = temp[x] ^ (~temp[(x + 1) % 5] & temp[(x + 2) % 5]);
            }

            state64[0] ^= roundConstant;
        }
    }

    static constexpr size_t rhoOffsets[24] = {
        1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14,
        27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44
    };

    static constexpr size_t piIndexes[24] = {
        10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4,
        15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1
    };

    static inline uint64_t rotl64(uint64_t x, uint64_t n) {
        return (x << n) | (x >> (64 - n));
    }

    void printHash(const uint8_t* hash, size_t length) {
        for (size_t i = 0; i < length; ++i) {
            std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];
        }
        std::cout << std::dec << std::endl;
    }

    bool runTest(const std::vector<uint8_t>& message, const std::vector<uint8_t>& expectedHash) {
        Keccak256 keccak;
        keccak.update(message.data(), message.size());
        uint8_t hash[32];
        keccak.finalize(hash);
        bool passed = std::equal(hash, hash + 32, expectedHash.begin());
        std::cout << (passed ? "PASS" : "FAIL") << " - ";
        printHash(hash, 32);
        return passed;
    }
};