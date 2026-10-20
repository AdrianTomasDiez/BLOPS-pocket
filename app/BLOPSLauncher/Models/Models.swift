import Foundation

struct GameInstallation: Codable, Identifiable {
    let id: UUID
    var sourcePath: String
    var status: String
    var fileCount: Int
    var totalBytes: Int64
    var verifiedAt: Date?
}

struct MapInfo: Identifiable {
    let id: String
    let name: String
    let supported: Bool
}

struct PlayerProfile: Codable {
    var displayName: String
    var sensitivity: Double
    var graphicsQuality: String
    var audioMaster: Double
    var audioMusic: Double
    var audioSfx: Double
    var controlLayout: String
}