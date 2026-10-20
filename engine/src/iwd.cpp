#include "blops/iwd.hpp"

#include <zlib.h>

#include <cstdio>
#include <cstring>

namespace blops {
namespace {

constexpr std::uint32_t kLocalSig = 0x04034b50;
constexpr std::uint32_t kCentralSig = 0x02014b50;
constexpr std::uint32_t kEocdSig = 0x06054b50;
constexpr std::size_t kEocdMin = 22;
constexpr std::size_t kMaxComment = 0xFFFF;

struct FileGuard {
    std::FILE* fp = nullptr;
    ~FileGuard() { if (fp) std::fclose(fp); }
};

std::uint16_t u16(const unsigned char* p) {
    return static_cast<std::uint16_t>(p[0] | (p[1] << 8));
}
std::uint32_t u32(const unsigned char* p) {
    return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8) |
           (static_cast<std::uint32_t>(p[2]) << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}
std::uint64_t u64(const unsigned char* p) {
    return static_cast<std::uint64_t>(u32(p)) | (static_cast<std::uint64_t>(u32(p + 4)) << 32);
}

bool readAt(std::FILE* fp, std::uint64_t offset, void* dst, std::size_t len) {
    if (std::fseek(fp, static_cast<long>(offset), SEEK_SET) != 0) return false;
    return std::fread(dst, 1, len, fp) == len;
}

} // namespace

const IwdEntry* IwdArchive::find(const std::string& name) const {
    for (const auto& e : entries) {
        if (e.name == name) return &e;
    }
    return nullptr;
}

std::size_t IwdArchive::totalUncompressed() const {
    std::size_t total = 0;
    for (const auto& e : entries) total += static_cast<std::size_t>(e.uncompressedSize);
    return total;
}

IwdArchive openIwd(const std::string& path) {
    IwdArchive archive;
    FileGuard f{std::fopen(path.c_str(), "rb")};
    if (!f.fp) { archive.error = "iwd: cannot open " + path; return archive; }

    std::fseek(f.fp, 0, SEEK_END);
    const long size = std::ftell(f.fp);
    if (size < static_cast<long>(kEocdMin)) { archive.error = "iwd: file too small"; return archive; }

    // The end-of-central-directory record sits within the last 64 KiB + 22.
    const std::size_t tailLen = static_cast<std::size_t>(
        size < static_cast<long>(kEocdMin + kMaxComment) ? size : kEocdMin + kMaxComment);
    std::vector<unsigned char> tail(tailLen);
    if (!readAt(f.fp, static_cast<std::uint64_t>(size) - tailLen, tail.data(), tailLen)) {
        archive.error = "iwd: cannot read tail";
        return archive;
    }
    long eocd = -1;
    for (long i = static_cast<long>(tailLen) - static_cast<long>(kEocdMin); i >= 0; --i) {
        if (u32(tail.data() + i) == kEocdSig) { eocd = i; break; }
    }
    if (eocd < 0) { archive.error = "iwd: no end-of-central-directory record"; return archive; }

    const unsigned char* e = tail.data() + eocd;
    const std::uint16_t entryCount = u16(e + 10);
    const std::uint32_t cdSize = u32(e + 12);
    const std::uint32_t cdOffset = u32(e + 16);
    if (entryCount == 0xFFFF || cdOffset == 0xFFFFFFFF) {
        archive.error = "iwd: zip64 archives are not supported";
        return archive;
    }
    if (cdOffset + cdSize > static_cast<std::uint64_t>(size)) {
        archive.error = "iwd: central directory outside file";
        return archive;
    }

    std::vector<unsigned char> cd(cdSize);
    if (!cd.empty() && !readAt(f.fp, cdOffset, cd.data(), cdSize)) {
        archive.error = "iwd: cannot read central directory";
        return archive;
    }

    std::size_t pos = 0;
    archive.entries.reserve(entryCount);
    for (std::uint16_t i = 0; i < entryCount; ++i) {
        if (pos + 46 > cd.size() || u32(cd.data() + pos) != kCentralSig) {
            archive.error = "iwd: malformed central directory entry";
            return archive;
        }
        const unsigned char* r = cd.data() + pos;
        IwdEntry entry;
        entry.method = u16(r + 10);
        entry.crc32 = u32(r + 16);
        entry.compressedSize = u32(r + 20);
        entry.uncompressedSize = u32(r + 24);
        const std::uint16_t nameLen = u16(r + 28);
        const std::uint16_t extraLen = u16(r + 30);
        const std::uint16_t commentLen = u16(r + 32);
        entry.localHeaderOffset = u32(r + 42);
        if (pos + 46 + nameLen > cd.size()) {
            archive.error = "iwd: truncated entry name";
            return archive;
        }
        entry.name.assign(reinterpret_cast<const char*>(r + 46), nameLen);

        // zip64 extra block: sizes are 0xFFFFFFFF and live in the extra field.
        if (entry.uncompressedSize == 0xFFFFFFFF || entry.compressedSize == 0xFFFFFFFF) {
            std::size_t x = pos + 46 + nameLen;
            const std::size_t xEnd = x + extraLen;
            while (x + 4 <= xEnd) {
                const std::uint16_t id = u16(cd.data() + x);
                const std::uint16_t len = u16(cd.data() + x + 2);
                if (id == 0x0001 && x + 4 + len <= xEnd) {
                    const unsigned char* p = cd.data() + x + 4;
                    std::size_t rem = len;
                    if (entry.uncompressedSize == 0xFFFFFFFF && rem >= 8) {
                        entry.uncompressedSize = u64(p); p += 8; rem -= 8;
                    }
                    if (entry.compressedSize == 0xFFFFFFFF && rem >= 8) {
                        entry.compressedSize = u64(p); p += 8; rem -= 8;
                    }
                    break;
                }
                x += 4 + len;
            }
        }
        archive.entries.push_back(std::move(entry));
        pos += 46 + nameLen + extraLen + commentLen;
    }

    archive.valid = true;
    return archive;
}

bool readIwdEntry(const std::string& path, const IwdEntry& entry,
                  std::vector<std::uint8_t>& out, std::string& error) {
    FileGuard f{std::fopen(path.c_str(), "rb")};
    if (!f.fp) { error = "iwd: cannot open " + path; return false; }

    unsigned char local[30];
    if (!readAt(f.fp, entry.localHeaderOffset, local, sizeof(local)) || u32(local) != kLocalSig) {
        error = "iwd: bad local header for " + entry.name;
        return false;
    }
    const std::uint16_t nameLen = u16(local + 26);
    const std::uint16_t extraLen = u16(local + 28);
    const std::uint64_t dataOffset = entry.localHeaderOffset + 30 + nameLen + extraLen;

    std::vector<unsigned char> compressed(static_cast<std::size_t>(entry.compressedSize));
    if (!compressed.empty() && !readAt(f.fp, dataOffset, compressed.data(), compressed.size())) {
        error = "iwd: cannot read data for " + entry.name;
        return false;
    }

    if (entry.method == 0) {
        out = std::move(compressed);
    } else if (entry.method == 8) {
        out.assign(static_cast<std::size_t>(entry.uncompressedSize), 0);
        z_stream zs{};
        if (inflateInit2(&zs, -MAX_WBITS) != Z_OK) { error = "iwd: inflateInit failed"; return false; }
        zs.next_in = compressed.data();
        zs.avail_in = static_cast<uInt>(compressed.size());
        zs.next_out = out.data();
        zs.avail_out = static_cast<uInt>(out.size());
        const int status = inflate(&zs, Z_FINISH);
        inflateEnd(&zs);
        if (status != Z_STREAM_END) { error = "iwd: corrupt deflate stream for " + entry.name; return false; }
    } else {
        error = "iwd: unsupported compression method " + std::to_string(entry.method) +
                " for " + entry.name;
        return false;
    }

    const std::uint32_t crc = crc32(0, out.data(), static_cast<uInt>(out.size()));
    if (crc != entry.crc32) {
        error = "iwd: crc mismatch for " + entry.name;
        return false;
    }
    return true;
}

} // namespace blops