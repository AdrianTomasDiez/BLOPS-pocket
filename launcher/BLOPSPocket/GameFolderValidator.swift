import Foundation

/// Resultado de comprobar la carpeta del juego elegida por el usuario.
/// No lee ni carga ningún archivo del juego (reglas.md, fase 4).
enum GameFolderStatus: Equatable {
    case valid
    case notAFolder
    case missingZoneFolder
}

enum GameFolderValidator {
    /// Nombre de la subcarpeta que debe contener la carpeta del juego.
    static let zoneFolderName = "zone"

    /// Comprueba que `url` es una carpeta y que contiene una subcarpeta `zone`.
    /// Debe llamarse con el acceso de seguridad ya abierto para URLs de Archivos.
    static func validate(_ url: URL, fileManager: FileManager = .default) -> GameFolderStatus {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .notAFolder
        }

        let zoneURL = url.appendingPathComponent(zoneFolderName, isDirectory: true)
        var zoneIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: zoneURL.path, isDirectory: &zoneIsDirectory),
              zoneIsDirectory.boolValue else {
            return .missingZoneFolder
        }

        return .valid
    }
}
