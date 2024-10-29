
/*
    MIT License
    Author: Fred Kyung-jin Rezeau <fred@litemint.com>, 2024
    Permission is granted to use, copy, modify, and distribute this software for any purpose
    with or without fee.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
*/

#pragma once

std::vector<uint8_t> decodeAddress(const std::string& address) {
    const std::string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    if (address.length() != 56 || address[0] != 'G') {
        throw std::invalid_argument("Invalid Stellar address.");
    }
    std::vector<uint8_t> decoded(33);
    size_t buffer = 0;
    int count = 0;
    size_t id = 0;
    for (char c : address) {
        size_t index = alphabet.find(c);
        if (index == std::string::npos) {
            throw std::invalid_argument("Invalid Stellar address.");
        }
        buffer = (buffer << 5) | index;
        count += 5;
        if (count >= 8) {
            decoded[id++] = static_cast<uint8_t>((buffer >> (count - 8)) & 0xFF);
            count -= 8;
        }
    }
    decoded.erase(decoded.begin());
    return decoded;
}

std::vector<uint8_t> addressToXdr(const std::string& address) {
    std::vector<uint8_t> xdr = {0, 0, 0, 18, 0, 0, 0, 0, 0, 0, 0, 0};
    std::vector<uint8_t> key = decodeAddress(address);
    xdr.insert(xdr.end(), key.begin(), key.end());
    return xdr;
}

std::vector<uint8_t> base64Decode(const std::string &input) {
    const std::string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::vector<uint8_t> output;
    std::vector<int> T(256, -1);
    for (int i = 0; i < 64; i++) T[alphabet[i]] = i;
    int val = 0, valb = -8;
    for (uint8_t c : input) {
        if (T[c] == -1) break;
        val = (val << 6) + T[c];
        valb += 6;
        if (valb >= 0) {
            output.push_back(uint8_t((val >> valb) & 0xFF));
            valb -= 8;
        }
    }
    return output;
}

std::array<uint8_t, 12> i64ToXdr(int64_t value) {
    std::array<uint8_t, 12> xdr = {0, 0, 0, 5};
    for (int i = 4; i < 12; i++) {
        xdr[11 - (i - 4)] = static_cast<uint8_t>(value & 0xFF);
        value >>= 8;
    }
    return xdr;
}

std::vector<uint8_t> stringToXdr(const std::string& str) {
    std::vector<uint8_t> xdr = {0, 0, 0, 14};
    uint32_t len = str.size();
    xdr.push_back((len >> 24) & 0xFF);
    xdr.push_back((len >> 16) & 0xFF);
    xdr.push_back((len >> 8) & 0xFF);
    xdr.push_back(len & 0xFF);
    xdr.insert(xdr.end(), str.begin(), str.end());
    while (xdr.size() % 4 != 0) {
        xdr.push_back(0);
    }
    return xdr;
}

std::vector<uint8_t> hashToXdr(const std::string& hash) {
    std::vector<uint8_t> decoded = base64Decode(hash);
    std::vector<uint8_t> xdr(8 + decoded.size());
    xdr[0] = 0; xdr[1] = 0; xdr[2] = 0; xdr[3] = 13;
    xdr[4] = 0; xdr[5] = 0; xdr[6] = 0; xdr[7] = 32;
    std::copy(decoded.begin(), decoded.end(), xdr.begin() + 8);
    return xdr;
}

void printHex(const std::vector<uint8_t>& data) {
    for (const auto& byte : data) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)byte;
    }
    std::cout << std::dec << std::endl;
}