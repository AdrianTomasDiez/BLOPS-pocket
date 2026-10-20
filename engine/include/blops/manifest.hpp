#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace blops {

struct ManifestEntry {
    std::string path;
    std::uint64_t size = 0;
    std::string sha256; // optional; empty means size-only
};

struct FileOnDisk {
    std::string path;
    std::uint64_t size = 0;
    std::string sha256;
};

struct VerifyResult {
    bool ok = false;
    std::size_t checked = 0;
    std::size_t missing = 0;
    std::size_t mismatched = 0;
    std::vector<std::string> errors;
};

// Verifies that every expected manifest entry exists on disk with matching size
// (and hash when provided). Pure logic; file I/O is done by the caller.
VerifyResult verifyManifest(const std::vector<ManifestEntry>& expected,
                           const std::vector<FileOnDisk>& found);

} // namespace blops