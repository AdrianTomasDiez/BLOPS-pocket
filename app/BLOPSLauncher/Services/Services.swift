import Foundation
import UniformTypeIdentifiers

struct GameFileSummary: Codable, Equatable {
    var iwdCount: Int
    var ffCount: Int
    var totalBytes: Int64
    var lastScan: Date
    var location: String

    var hasArchives: Bool { iwdCount > 0 }
    var hasZones: Bool { ffCount > 0 }
    var isUsable: Bool { hasArchives && hasZones }

    var totalSizeText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
}

/// Locates and catalogues the user's own copy of Call of Duty: Black Ops.
/// Nothing is copied, uploaded or redistributed: the app only reads metadata
/// from files the user placed on their own device.
final class GameFileStore: ObservableObject {
    @Published private(set) var summary: GameFileSummary?
    @Published private(set) var isScanning = false
    @Published var message: String?

    private let bookmarkKey = "game.folder.bookmark"
    private let pathKey = "game.folder.path"

    init() {
        if let data = UserDefaults.standard.data(forKey: "game.folder.summary"),
           let saved = try? JSONDecoder().decode(GameFileSummary.self, from: data) {
            summary = saved
        }
    }

    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Scans the app's own Documents folder, which is where Finder / Apple
    /// Devices file sharing drops the user's `main` and `zone` folders.
    func scanDocuments() {
        scan(url: documentsURL, persist: false)
    }

    func importFolder(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        scan(url: url, persist: true) {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
    }

    func rescanSavedFolder() {
        guard let url = savedFolderURL() else {
            message = "No folder saved yet."
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        scan(url: url, persist: false) {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
    }

    private func savedFolderURL() -> URL? {
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: [],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                return url
            }
        }
        if let path = UserDefaults.standard.string(forKey: pathKey) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func scan(url: URL, persist: Bool, completion: (() -> Void)? = nil) {
        isScanning = true
        message = nil
        let location = url.lastPathComponent

        DispatchQueue.global(qos: .userInitiated).async {
            var iwd = 0
            var ff = 0
            var bytes: Int64 = 0

            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            let enumerator = FileManager.default.enumerator(at: url,
                                                            includingPropertiesForKeys: keys,
                                                            options: [.skipsHiddenFiles])
            while let file = enumerator?.nextObject() as? URL {
                guard let values = try? file.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }
                let ext = file.pathExtension.lowercased()
                guard ext == "iwd" || ext == "ff" else { continue }
                bytes += Int64(values.fileSize ?? 0)
                if ext == "iwd" { iwd += 1 } else { ff += 1 }
            }

            let result = GameFileSummary(iwdCount: iwd,
                                         ffCount: ff,
                                         totalBytes: bytes,
                                         lastScan: Date(),
                                         location: location)

            DispatchQueue.main.async {
                self.isScanning = false
                if result.isUsable {
                    self.summary = result
                    self.persist(result, url: persist ? url : nil)
                    self.message = "Found \(iwd) .iwd and \(ff) .ff files (\(result.totalSizeText))."
                } else {
                    self.message = iwd + ff == 0
                        ? "No game files found in \(location). Copy the main and zone folders here, then scan again."
                        : "Incomplete: found \(iwd) .iwd and \(ff) .ff. Both folders are required."
                }
                completion?()
            }
        }
    }

    private func persist(_ summary: GameFileSummary, url: URL?) {
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: "game.folder.summary")
        }
        if let url {
            UserDefaults.standard.set(url.path, forKey: pathKey)
            if let bookmark = try? url.bookmarkData(options: .minimalBookmark,
                                                    includingResourceValuesForKeys: nil,
                                                    relativeTo: nil) {
                UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            }
        }
    }
}

final class ProfileService: ObservableObject {
    @Published var profile = PlayerProfile(displayName: "Player",
                                           sensitivity: 1.0,
                                           graphicsQuality: "medium",
                                           audioMaster: 1.0,
                                           audioMusic: 1.0,
                                           audioSfx: 1.0,
                                           controlLayout: "default")

    private let key = "player.profile"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            profile = saved
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
