#pragma once
#include <array>
#include <cstdint>
#include <string>

namespace blops {

// Minimal SHA-256 (FIPS 180-4). Used for manifest generation and verification.
// No OpenSSL dependency, so the same code builds for iOS and CI.
using Sha256Digest = std::array<std::uint8_t, 32>;

Sha256Digest sha256(const std::uint8_t* data, std::size_t len);
bool sha256File(const std::string& path, Sha256Digest& out);
std::string toHex(const Sha256Digest& d);

} // namespace blops