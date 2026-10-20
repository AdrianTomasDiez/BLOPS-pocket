#pragma once
#include <cstdint>
#include <cstddef>
#include <string>
#include <vector>

namespace blops {

// Treyarch T5 (Black Ops 1) FastFile / "zone".
//
// On-disk layout, verified against the retail Steam files:
//   offset 0   : 8-byte ASCII magic, "IWffu100"
//   offset 8   : uint32 little-endian format version (473 on the retail build)
//   offset 12  : a single zlib stream (RFC 1950) holding the whole zone
//
// The zone body itself is asset data; walking it is a separate concern
// (zone assets), this class only handles the container.

struct ZoneHeader {
    std::string magic;
    std::uint32_t version = 0;
    bool isT5() const { return magic == "IWffu100"; }
};

struct ZoneInfo {
    ZoneHeader header;
    std::uint64_t fileBytes = 0;
    std::uint64_t inflatedBytes = 0;
    bool valid = false;
    std::string error;
};

// Reads only the container header and, when withSize is true, inflates the
// stream to learn the exact uncompressed size. Nothing is kept in memory
// beyond the requested block, so a 100 MB zone costs a few KB.
ZoneInfo inspectZone(const std::string& path, bool withSize = true);

// Inflates the zone body. `maxBytes` caps the output (0 means unlimited) so a
// corrupt file cannot exhaust memory on a phone.
bool readZoneBody(const std::string& path, std::vector<std::uint8_t>& out,
                  std::size_t maxBytes, std::string& error);

} // namespace blops