import Foundation
import UniformTypeIdentifiers

final class InstallationService: ObservableObject {
    @Published var status: String = "Not verified"

    func importFolder() async throws -> URL {
        // iOS document picker returns a security-scoped URL; caller must persist bookmark.
        throw NSError(domain: "BLOPS", code: 1, userInfo: [NSLocalizedDescriptionKey: "Implement document picker in view"])
    }

    func verify(at url: URL) async -> Bool {
        // TODO: load manifest, hash files, compare.
        return false
    }
}

final class ProfileService: ObservableObject {
    @Published var profile = PlayerProfile(displayName: "Player", sensitivity: 1.0, graphicsQuality: "medium", audioMaster: 1.0, audioMusic: 1.0, audioSfx: 1.0, controlLayout: "default")

    func save() {
        // TODO: persist to SQLite/UserDefaults
    }
}