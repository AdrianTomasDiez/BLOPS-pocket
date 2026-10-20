#pragma once
#include <string>
#include <vector>

namespace blops {

// Scans a Call of Duty: Black Ops install directory and lists every file the
// engine needs to verify before playing.
//   main/*.iwd        visuals/sounds/assets
//   zone/**/*.ff      level zones (main + Common + language zones)
std::vector<std::string> listGameFiles(const std::string& gameDir);

// Optional manifest JSON writer. `gameDir` anchors the paths so the manifest
// verifies on a different machine than it was generated on.
bool writeManifestJson(const std::string& gameDir,
                       const std::vector<std::string>& relativePaths,
                       const std::string& outPath,
                       bool withHashes,
                       std::string& error);

} // namespace blops