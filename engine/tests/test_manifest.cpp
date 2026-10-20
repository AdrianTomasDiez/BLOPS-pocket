#include "blops/manifest.hpp"
#include <cassert>
#include <iostream>

int main() {
    using namespace blops;
    std::vector<ManifestEntry> expected = {
        {"main/iw_01.iwd", 100, "abc"},
        {"zone/common/kino.ff", 200, ""}
    };
    std::vector<FileOnDisk> found = {
        {"main/iw_01.iwd", 100, "abc"},
        {"zone/common/kino.ff", 200, ""}
    };
    auto r = verifyManifest(expected, found);
    assert(r.ok);
    assert(r.checked == 2);

    // missing
    std::vector<FileOnDisk> found2 = {{"main/iw_01.iwd", 100, "abc"}};
    auto r2 = verifyManifest(expected, found2);
    assert(!r2.ok);
    assert(r2.missing == 1);

    // mismatch size
    std::vector<FileOnDisk> found3 = {{"main/iw_01.iwd", 99, "abc"}, {"zone/common/kino.ff", 200, ""}};
    auto r3 = verifyManifest(expected, found3);
    assert(!r3.ok);
    assert(r3.mismatched == 1);

    std::cout << "manifest tests passed\n";
    return 0;
}