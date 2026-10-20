#include "blops/scan.hpp"
#include "blops/zone.hpp"
#include "blops/iwd.hpp"
#include "blops/sha256.hpp"

#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace blops {
namespace fs = std::filesystem;

static void walkDirectory(const fs::path& root,
                           const fs::path& current,
                           std::vector<std::string>& out) {
    if (!fs::exists(current)) return;
    for (const auto& e : fs::directory_iterator(current)) {
        if (e.is_directory()) {
            walkDirectory(root, e.path(), out);
        } else if (e.is_regular_file()) {
            const std::string ext = e.path().extension().string();
            if (ext == ".iwd" || ext == ".ff") {
                const std::string rel = fs::relative(e.path(), root).string();
                out.push_back(rel);
            }
        }
    }
}

std::vector<std::string> listGameFiles(const std::string& gameDir) {
    std::vector<std::string> out;
    fs::path root(gameDir);
    // main/*.iwd
    fs::path main = root / "main";
    if (fs::exists(main)) {
        for (const auto& e : fs::directory_iterator(main)) {
            if (e.is_regular_file() && e.path().extension() == ".iwd") {
                out.push_back("main/" + e.path().filename().string());
            }
        }
    }
    // zone/**/*.ff
    fs::path zone = root / "zone";
    if (fs::exists(zone)) {
        for (const auto& dir : fs::directory_iterator(zone)) {
            if (dir.is_directory()) {
                for (const auto& f : fs::directory_iterator(dir.path())) {
                    if (f.is_regular_file() && f.path().extension() == ".ff") {
                        out.push_back("zone/" + dir.path().filename().string() + "/" +
                                      f.path().filename().string());
                    }
                }
            }
        }
    }
    return out;
}

bool writeManifestJson(const std::string& gameDir,
                       const std::vector<std::string>& relPaths,
                       const std::string& outPath,
                       bool withHashes,
                       std::string& error) {
    std::ofstream out(outPath);
    if (!out) { error = "scan: cannot write " + outPath; return false; }
    out << "[\n";
    for (size_t i = 0; i < relPaths.size(); ++i) {
        const std::string rel = relPaths[i];
        const fs::path full = fs::path(gameDir) / rel;
        std::uint64_t size = 0;
        std::string sha = "";
        if (fs::exists(full)) {
            size = fs::file_size(full);
            if (withHashes) {
                Sha256Digest d{};
                if (sha256File(full.string(), d)) sha = toHex(d);
            }
        }
        out << "  {\"path\":\"" << rel << "\",\"size\":" << size;
        if (withHashes) out << ",\"sha256\":\"" << sha << "\"";
        out << "}";
        if (i + 1 < relPaths.size()) out << ",";
        out << "\n";
    }
    out << "]\n";
    return true;
}

} // namespace blops