#include "blops/zone.hpp"
#include "blops/iwd.hpp"
#include "blops/scan.hpp"
#include <cstdlib>
#include <iostream>

static const char* kDefaultGame =
    "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops";

int main(int argc, char** argv) {
    const char* env = std::getenv("BLOPS_GAME_DIR");
    const std::string game = env ? env : kDefaultGame;

    auto files = blops::listGameFiles(game);
    std::cout << "game dir: " << game << "\n";
    std::cout << "files found: " << files.size() << "\n";

    if (argc > 2 && std::string(argv[1]) == "--manifest") {
        std::string err;
        if (!blops::writeManifestJson(game, files, argv[2], true, err)) {
            std::cout << "manifest error: " << err << "\n";
            return 1;
        }
        std::cout << "manifest written: " << argv[2] << "\n";
        return 0;
    }

    std::size_t iwdCount = 0, ffCount = 0;
    for (const auto& rel : files) {
        if (rel.rfind("main/", 0) == 0) ++iwdCount; else ++ffCount;
    }
    std::cout << "iwd: " << iwdCount << "  ff: " << ffCount << "\n";

    // Inspect the first zone to prove the container parser works.
    for (const auto& rel : files) {
        if (rel.size() > 3 && rel.substr(rel.size() - 3) == ".ff") {
            auto info = blops::inspectZone(game + "\\" + rel);
            std::cout << rel << "\n";
            std::cout << "  magic=" << info.header.magic << " version=" << info.header.version
                      << " file=" << info.fileBytes << " inflated=" << info.inflatedBytes << "\n";
            break;
        }
    }
    // Inspect the first archive.
    for (const auto& rel : files) {
        if (rel.size() > 4 && rel.substr(rel.size() - 4) == ".iwd") {
            auto a = blops::openIwd(game + "\\" + rel);
            std::cout << rel << ": entries=" << a.entries.size()
                      << " valid=" << (a.valid ? "yes" : "no");
            if (!a.valid) std::cout << " error=" << a.error;
            std::cout << "\n";
            break;
        }
    }
    return 0;
}