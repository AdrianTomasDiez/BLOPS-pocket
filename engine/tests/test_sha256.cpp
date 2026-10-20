#include "blops/sha256.hpp"
#include <cassert>
#include <cstring>
#include <iostream>

int main() {
    using namespace blops;
    // Known vectors (FIPS 180-4).
    {
        const char* s = "abc";
        auto d = sha256(reinterpret_cast<const std::uint8_t*>(s), 3);
        assert(toHex(d) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    }
    {
        const char* s = "";
        auto d = sha256(reinterpret_cast<const std::uint8_t*>(s), 0);
        assert(toHex(d) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    }
    {
        const char* s = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        auto d = sha256(reinterpret_cast<const std::uint8_t*>(s), std::strlen(s));
        assert(toHex(d) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
    }
    std::cout << "sha256 tests passed\n";
    return 0;
}