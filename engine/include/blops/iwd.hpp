#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace blops {

// .iwd archives are plain ZIP files (deflate or store) with no compression
// tricks of their own. The engine only needs the central directory: name,
// sizes and offsets. Asset bytes are inflated on demand.

struct IwdEntry {
    std::string name;
    std::uint32_t crc32 = 0;
    std::uint64_t compressedSize = 0;
    std::uint64_t uncompressedSize = 0;
    std::uint64_t localHeaderOffset = 0;
    std::uint16_t method = 0; // 0 = stored, 8 = deflate
};

struct IwdArchive {
    std::vector<IwdEntry> entries;
    bool valid = false;
    std::string error;

    const IwdEntry* find(const std::string& name) const;
    std::size_t totalUncompressed() const;
};

// Parses the central directory only. Cheap: a few seeks, no full read.
IwdArchive openIwd(const std::string& path);

// Reads and inflates one entry. Returns false and sets error on corruption.
bool readIwdEntry(const std::string& path, const IwdEntry& entry,
                  std::vector<std::uint8_t>& out, std::string& error);

} // namespace blops