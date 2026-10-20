#include "blops/zone.hpp"

#include "miniz.h"

#include <cstdio>
#include <cstring>
#include <vector>

namespace blops {
namespace {

constexpr std::size_t kChunk = 64 * 1024;
constexpr std::size_t kHeaderBytes = 12;

struct FileGuard {
    std::FILE* fp = nullptr;
    ~FileGuard() { if (fp) std::fclose(fp); }
};

bool readHeader(std::FILE* fp, ZoneHeader& out, std::string& error) {
    unsigned char raw[kHeaderBytes];
    if (std::fread(raw, 1, sizeof(raw), fp) != sizeof(raw)) {
        error = "zone: file shorter than header";
        return false;
    }
    out.magic.assign(reinterpret_cast<char*>(raw), 8);
    out.version = static_cast<std::uint32_t>(raw[8]) |
                  (static_cast<std::uint32_t>(raw[9]) << 8) |
                  (static_cast<std::uint32_t>(raw[10]) << 16) |
                  (static_cast<std::uint32_t>(raw[11]) << 24);
    if (!out.isT5()) {
        error = "zone: unexpected magic " + out.magic;
        return false;
    }
    return true;
}

} // namespace

ZoneInfo inspectZone(const std::string& path, bool withSize) {
    ZoneInfo info;
    FileGuard f{std::fopen(path.c_str(), "rb")};
    if (!f.fp) { info.error = "zone: cannot open " + path; return info; }
    std::fseek(f.fp, 0, SEEK_END);
    info.fileBytes = static_cast<std::uint64_t>(std::ftell(f.fp));
    std::fseek(f.fp, 0, SEEK_SET);

    if (!readHeader(f.fp, info.header, info.error)) return info;
    if (!withSize) { info.valid = true; return info; }

    z_stream zs{};
    if (inflateInit(&zs) != Z_OK) { info.error = "zone: inflateInit failed"; return info; }

    std::vector<unsigned char> in(kChunk), out(kChunk);
    int status = Z_OK;
    std::uint64_t produced = 0;
    bool ioError = false;

    for (;;) {
        if (zs.avail_in == 0) {
            const std::size_t got = std::fread(in.data(), 1, in.size(), f.fp);
            if (got == 0) { status = Z_BUF_ERROR; break; }
            zs.next_in = in.data();
            zs.avail_in = static_cast<uInt>(got);
        }
        zs.next_out = out.data();
        zs.avail_out = static_cast<uInt>(out.size());
        status = inflate(&zs, Z_NO_FLUSH);
        produced += out.size() - zs.avail_out;
        if (status == Z_STREAM_END) break;
        if (status != Z_OK) { ioError = true; break; }
    }
    inflateEnd(&zs);

    if (status != Z_STREAM_END) {
        info.error = ioError ? "zone: corrupt zlib stream" : "zone: truncated zlib stream";
        return info;
    }
    info.inflatedBytes = produced;
    info.valid = true;
    return info;
}

bool readZoneBody(const std::string& path, std::vector<std::uint8_t>& out,
                  std::size_t maxBytes, std::string& error) {
    FileGuard f{std::fopen(path.c_str(), "rb")};
    if (!f.fp) { error = "zone: cannot open " + path; return false; }
    ZoneHeader header;
    if (!readHeader(f.fp, header, error)) return false;

    z_stream zs{};
    if (inflateInit(&zs) != Z_OK) { error = "zone: inflateInit failed"; return false; }

    std::vector<unsigned char> in(kChunk), chunk(kChunk);
    out.clear();
    int status = Z_OK;

    for (;;) {
        if (zs.avail_in == 0) {
            const std::size_t got = std::fread(in.data(), 1, in.size(), f.fp);
            if (got == 0) { status = Z_BUF_ERROR; break; }
            zs.next_in = in.data();
            zs.avail_in = static_cast<uInt>(got);
        }
        zs.next_out = chunk.data();
        zs.avail_out = static_cast<uInt>(chunk.size());
        status = inflate(&zs, Z_NO_FLUSH);
        const std::size_t produced = chunk.size() - zs.avail_out;
        if (maxBytes != 0 && out.size() + produced > maxBytes) {
            inflateEnd(&zs);
            error = "zone: body exceeds limit";
            return false;
        }
        out.insert(out.end(), chunk.begin(), chunk.begin() + static_cast<std::ptrdiff_t>(produced));
        if (status == Z_STREAM_END) break;
        if (status != Z_OK) { inflateEnd(&zs); error = "zone: corrupt zlib stream"; return false; }
    }
    inflateEnd(&zs);
    if (status != Z_STREAM_END) { error = "zone: truncated zlib stream"; return false; }
    return true;
}

} // namespace blops