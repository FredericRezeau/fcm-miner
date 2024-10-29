/*
    MIT License
    Author: Fred Kyung-jin Rezeau <fred@litemint.com>, 2024
    Permission is granted to use, copy, modify, and distribute this software for any purpose
    with or without fee.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
*/

#include <iostream>
#include <vector>
#include <array>
#include <cstdint>
#include <chrono>
#include <iomanip>
#include <atomic>
#include <thread>
#include <mutex>
#include <functional>

#include "utils/keccak.h"
#include "utils/misc.h"

static const std::uint64_t defaultBatchSize = 10000000;
static const int defaultMaxThreads = 4;
static const int hashRateInterval = 5000;
static std::atomic<bool> found(false);
static std::atomic<std::uint64_t> totalHashes(0);

bool check(const std::vector<uint8_t>& hash, int difficulty) {
   int zeroes = 0;
    for (uint8_t byte : hash) {
        zeroes += (byte == 0) ? 2 : ((byte >> 4) == 0 ? 1 : 0);
        if (byte != 0 || zeroes >= difficulty) break;
    }
    return zeroes >= difficulty;
}

std::pair<std::vector<uint8_t>, std::uint64_t> find(std::uint64_t block, const std::string& base64Hash,
    std::uint64_t nonce, int difficulty, const std::string& message, const std::string& miner, bool verbose, std::uint64_t batchSize) {

    auto blockXdr = i64ToXdr(block);
    auto nonceXdr = i64ToXdr(nonce);
    auto hashXdr = hashToXdr(base64Hash);
    auto messageXdr = stringToXdr(message);
    auto minerXdr = addressToXdr(miner);

    std::vector<uint8_t> data;
    data.insert(data.end(), blockXdr.begin(), blockXdr.end());
    data.insert(data.end(), messageXdr.begin(), messageXdr.end());
    data.insert(data.end(), hashXdr.begin(), hashXdr.end());
    data.insert(data.end(), nonceXdr.begin(), nonceXdr.end());
    data.insert(data.end(), minerXdr.begin(), minerXdr.end());

    size_t nonceOffset = blockXdr.size() + messageXdr.size() + hashXdr.size();
    std::uint64_t counter = 0;
    int hashRateCounter = 0;

    if (verbose) {
        std::cout << "Mining: batch: " << nonce << " block: " << block << " difficulty: " << difficulty << " hash: " << base64Hash << std::endl;
        std::cout.flush();
    } 

    Keccak256 keccak;
    while (!found.load()) {
        auto nonceBytes = i64ToXdr(nonce);
        std::copy(nonceBytes.begin(), nonceBytes.end(), data.begin() + nonceOffset);

        keccak.reset();
        keccak.update(data.data(), data.size());
        std::vector<uint8_t> result(32);
        keccak.finalize(result.data());

        if (check(result, difficulty)) {
            return {result, nonce};
        }

        nonce++;
        counter++;
        if (counter == batchSize) {
            break;
        }

        hashRateCounter += 1;
        if(hashRateCounter == hashRateInterval){
            totalHashes.fetch_add(hashRateCounter, std::memory_order_relaxed);
            hashRateCounter = 0;
        }
    }
    return {{}, 0};
}

void monitorHashRate(bool verbose) {
    auto startTime = std::chrono::high_resolution_clock::now();
    while (!found.load()) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
        auto currentTime = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> elapsedTime = currentTime - startTime;
        double hashRate = totalHashes.load() / elapsedTime.count();
        if (verbose && hashRate > 0) {
            std::cout << std::fixed << std::setprecision(2) << "Hash Rate: " << hashRate << " hash/sec\n";
            std::cout.flush();
        }
        startTime = currentTime;
        totalHashes.store(0);
    }
}

int main(int argc, char* argv[]) {
    if (argc < 7) {
        std::cerr << "Usage: " << argv[0]
            << " <block> <hash> <nonce> <difficulty> <message> <miner_address>\n"
            << "  [--max-threads <num> (default: " << defaultMaxThreads << ")]\n"
            << "  [--batch-size <num> (default: " << defaultBatchSize << ")]\n"
            << "  [--verbose]\n";
        return 1;
    }

    int64_t block = std::stoll(argv[1]);
    std::string hash = argv[2];
    int64_t nonce = std::stoll(argv[3]);
    int difficulty = std::stoi(argv[4]);
    std::string message = argv[5];
    std::string miner = argv[6];

    bool verbose = false;
    std::uint64_t batchSize = defaultBatchSize;
    int maxThreads = defaultMaxThreads;
    for (int i = 7; i < argc; ++i) {
        if (std::strcmp(argv[i], "--max-threads") == 0 && i + 1 < argc) {
            maxThreads = std::stoi(argv[++i]);
        } else if (std::strcmp(argv[i], "--batch-size") == 0 && i + 1 < argc) {
            batchSize = std::stoll(argv[++i]);
        } else if (std::strcmp(argv[i], "--verbose") == 0) {
            verbose = true;
        }
    }

    try {
        std::thread monitorThread(monitorHashRate, verbose);

        std::uint64_t currentNonce = nonce;
        std::vector<std::thread> threads;
        std::pair<std::vector<uint8_t>, std::uint64_t> result;
        std::mutex resultMutex;
        while (!found.load()) {
            while (threads.size() < maxThreads && !found.load()) {
                std::uint64_t endNonce = currentNonce + batchSize;
                threads.emplace_back([&, startNonce = currentNonce, endNonce]() {
                    auto localResult = find(block, hash, startNonce, difficulty, message, miner, verbose, batchSize);
                    if (!localResult.first.empty()) {
                        std::lock_guard<std::mutex> lock(resultMutex);
                        result = localResult;
                        found.store(true);
                    }
                });
                currentNonce = endNonce;
            }
            threads.erase(std::remove_if(threads.begin(), threads.end(),
                [](std::thread& t) { 
                    if (t.joinable()) { 
                        t.join(); 
                        return true; 
                    }
                    return false;
                }), threads.end());
        }

        for (auto& t : threads) {
            if (t.joinable()) {
                t.join();
            }
        }

        if (!result.first.empty()) {
            std::cout << "{\n"
                    << "  \"hash\": \"";
            for (const auto& byte : result.first) {
                printf("%02x", byte);
            }
            std::cout << "\",\n"
                    << "  \"nonce\": " << result.second << "\n"
                    << "}\n";
        } else {
            std::cout << "No valid hash found.\n";
        }

        monitorThread.detach();
    }
    catch (const std::exception& e) {
        std::cerr << "Exception: " << e.what() << std::endl;
    }
    return 0;
}