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

/// One file discovered during the import scan.
struct DiscoveredFile: Codable, Equatable, Identifiable {
    var path: String          // relative to the scanned root
    var size: Int64
    var isArchive: Bool       // .iwd
    var isZone: Bool          // .ff
    var id: String { path }
}

enum FileCheck: Equatable {
    case ok
    case missing
    case sizeMismatch(expected: Int64, actual: Int64)
    case badHeader(expected: String, actual: String)
    case unreadable
}

struct VerifyReport: Equatable {
    var checked: Int = 0
    var ok: Int = 0
    var problems: [String] = []
    var isValid: Bool { problems.isEmpty && checked > 0 }
}

/// Locates and catalogues the user's own copy of Call of Duty: Black Ops.
/// Nothing is copied, uploaded or redistributed: the app only reads metadata
/// and file headers from files the user placed on their own device.
final class GameFileStore: ObservableObject {
    @Published private(set) var summary: GameFileSummary?
    @Published private(set) var files: [DiscoveredFile] = []
    @Published private(set) var isScanning = false
    @Published private(set) var isVerifying = false
    @Published var message: String?

    private let bookmarkKey = "game.folder.bookmark"
    private let pathKey = "game.folder.path"
    private let summaryKey = "game.folder.summary"
    private let filesKey = "game.folder.files"

    init() {
        if let data = UserDefaults.standard.data(forKey: summaryKey),
           let saved = try? JSONDecoder().decode(GameFileSummary.self, from: data) {
            summary = saved
        }
        if let data = UserDefaults.standard.data(forKey: filesKey),
           let saved = try? JSONDecoder().decode([DiscoveredFile].self, from: data) {
            files = saved
        }
    }

    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Root of the imported game folder, if one was chosen earlier.
    var rootURL: URL? { savedFolderURL() }

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
            message = "No folder saved yet. Use \"Select folder\" to choose one."
            return
        }
        let scoped = url.startAccessingSecurityScopedResource()
        scan(url: url, persist: true) {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
    }

    func savedFolderURL() -> URL? {
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data,
                                  options: resolveOptions,
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

    #if os(iOS)
    private var resolveOptions: URL.BookmarkResolutionOptions { [.withSecurityScope] }
#if os(iOS)
    private var createOptions: URL.BookmarkCreationOptions { [] }
#else
    private var createOptions: URL.BookmarkCreationOptions { [.withSecurityScope] }
#endif
    #else
    private var resolveOptions: URL.BookmarkResolutionOptions { [] }
    private var createOptions: URL.BookmarkCreationOptions { [] }
    #endif

    private func scan(url: URL, persist: Bool, completion: (() -> Void)? = nil) {
        isScanning = true
        message = nil
        let location = url.lastPathComponent

        DispatchQueue.global(qos: .userInitiated).async {
            var iwd = 0
            var ff = 0
            var bytes: Int64 = 0
            var found: [DiscoveredFile] = []

            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            let enumerator = FileManager.default.enumerator(at: url,
                                                            includingPropertiesForKeys: keys,
                                                            options: [.skipsHiddenFiles])
            while let file = enumerator?.nextObject() as? URL {
                guard let values = try? file.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }
                let ext = file.pathExtension.lowercased()
                guard ext == "iwd" || ext == "ff" else { continue }
                let size = Int64(values.fileSize ?? 0)
                bytes += size
                if ext == "iwd" { iwd += 1 } else { ff += 1 }
                let relative = url.path.hasSuffix("/")
                    ? String(file.path.dropFirst(url.path.count))
                    : String(file.path.dropFirst(min(url.path.count, file.path.count)))
                found.append(DiscoveredFile(path: relative,
                                            size: size,
                                            isArchive: ext == "iwd",
                                            isZone: ext == "ff"))
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
                    self.files = found
                    self.persist(result, files: found, url: persist ? url : nil)
                    self.message = "Found \(iwd) .iwd and \(ff) .ff files (\(result.totalSizeText))."
                } else {
                    if iwd + ff == 0 {
                        if let existing = self.summary {
                            self.message = "No files in \(location). Your game files are in \"\(existing.location)\"."
                        } else {
                            self.message = "No game files found in \(location). Choose the folder that contains main/ and zone/."
                        }
                    } else {
                        self.message = "Incomplete: found \(iwd) .iwd and \(ff) .ff. Both folders are required."
                    }
                }
                completion?()
            }
        }
    }

    /// Structural check of every discovered file: exists, expected size and a
    /// valid container header (IWD = ZIP signature, FF = IWffu100 fastfile).
    func verify(completion: @escaping (VerifyReport) -> Void) {
        guard let root = rootURL else {
            let report = VerifyReport(problems: ["No game folder selected. Use Import to choose one."])
            completion(report)
            return
        }

        isVerifying = true
        let target = files
        let rootPath = root.path

        DispatchQueue.global(qos: .userInitiated).async {
            let scoped = root.startAccessingSecurityScopedResource()
            defer { if scoped { root.stopAccessingSecurityScopedResource() } }

            var report = VerifyReport()
            for file in target {
                report.checked += 1
                let full = URL(fileURLWithPath: rootPath).appendingPathComponent(file.path)
                guard FileManager.default.fileExists(atPath: full.path) else {
                    report.problems.append("Missing: \(file.path)")
                    continue
                }
                let attrs = try? FileManager.default.attributesOfItem(atPath: full.path)
                let actualSize = (attrs?[.size] as? NSNumber)?.int64Value ?? -1
                if actualSize != file.size {
                    report.problems.append("Size mismatch: \(file.path)")
                    continue
                }
                let header = Self.readHeader(full, length: 12)
                if header == nil {
                    report.problems.append("Unreadable: \(file.path)")
                    continue
                }
                if file.isArchive {
                    // IWD files are ZIP archives: "PK\x03\x04".
                    if !header!.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
                        report.problems.append("Bad IWD header: \(file.path)")
                        continue
                    }
                } else {
                    // Zone files start with the IWffu100 fastfile magic.
                    let magic = String(bytes: header!.prefix(8), encoding: .ascii) ?? ""
                    if magic != "IWffu100" {
                        report.problems.append("Bad FF header: \(file.path) (found \(magic))")
                        continue
                    }
                }
                report.ok += 1
            }

            DispatchQueue.main.async {
                self.isVerifying = false
                completion(report)
            }
        }
    }

    private static func readHeader(_ url: URL, length: Int) -> [UInt8]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: length) else { return nil }
        return [UInt8](data)
    }

    private func persist(_ summary: GameFileSummary, files: [DiscoveredFile], url: URL?) {
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: summaryKey)
        }
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: filesKey)
        }
        if let url {
            UserDefaults.standard.set(url.path, forKey: pathKey)
            if let bookmark = try? url.bookmarkData(options: createOptions,
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
