#include "blops/manifest.hpp"

namespace blops {

VerifyResult verifyManifest(const std::vector<ManifestEntry>& expected,
                           const std::vector<FileOnDisk>& found) {
    VerifyResult result;
    // Index found files by path for O(1) lookup.
    // Simple linear search keeps this dependency-free.
    for (const auto& entry : expected) {
        // find
        const FileOnDisk* match = nullptr;
        for (const auto& f : found) {
            if (f.path == entry.path) { match = &f; break; }
        }
        if (!match) {
            result.missing++;
            result.errors.push_back("missing: " + entry.path);
            continue;
        }
        bool sizeOk = (match->size == entry.size);
        bool hashOk = entry.sha256.empty() || (match->sha256 == entry.sha256);
        if (!sizeOk || !hashOk) {
            result.mismatched++;
            result.errors.push_back("mismatch: " + entry.path);
            continue;
        }
        result.checked++;
    }
    result.ok = (result.missing == 0 && result.mismatched == 0 && !expected.empty());
    return result;
}

} // namespace blops