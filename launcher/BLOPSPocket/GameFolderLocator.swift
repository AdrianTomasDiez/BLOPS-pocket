import Foundation

/// Busca la carpeta del juego dentro del contenedor de la app.
///
/// Es la vía recomendada (reglas.md, secciones 4 y 10): el usuario copia el
/// juego en **Archivos → En mi iPhone → BLOPS pocket → Games** y la app lo lee
/// de su propio contenedor, sin depender de un bookmark ni de que iCloud tenga
/// los archivos descargados. `UIFileSharingEnabled` y
/// `LSSupportsOpeningDocumentsInPlace` en el Info.plist hacen que esa carpeta
/// sea visible en Archivos.
enum GameFolderLocator {
    /// Subcarpeta donde se espera el juego, como IW4-Pocket.
    static let gamesFolderName = "Games"

    /// Busca una carpeta válida (con subcarpeta `zone`) dentro de Documents.
    /// Se mira en `Documents/Games`, en `Documents` y entre sus hijos directos.
    /// Crea `Documents/Games` si no existe para que el usuario la vea vacía en Archivos.
    static func findInDocuments(fileManager: FileManager = .default) -> URL? {
        guard let documents = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        let games = documents.appendingPathComponent(gamesFolderName, isDirectory: true)
        try? fileManager.createDirectory(at: games, withIntermediateDirectories: true)

        var candidates: [URL] = [games, documents]
        for root in [games, documents] {
            let children = (try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            candidates.append(contentsOf: children)
        }

        return candidates.first { GameFolderValidator.validate($0, fileManager: fileManager) == .valid }
    }
}
