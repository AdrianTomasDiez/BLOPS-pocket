import Foundation

/// Grupo de zona, por subcarpeta (idioma) y prefijo del nombre.
/// Equivalente a `zoneGroup` en tools/zonescan.mjs: si cambia uno, cambiar el otro.
enum ZoneGroup: String, CaseIterable {
    case zombies
    case common
    case code
    case multiplayer
    case interface
    case patch
    case campaign
    case translation

    var displayName: String {
        switch self {
        case .zombies: return "Zombies"
        case .common: return "Comunes"
        case .code: return "Código"
        case .multiplayer: return "Multijugador"
        case .interface: return "Interfaz"
        case .patch: return "Parches"
        case .campaign: return "Campaña"
        case .translation: return "Traducciones"
        }
    }

    /// Clasifica usando la ruta relativa dentro de la carpeta `zone`.
    static func classify(relativePath: String) -> ZoneGroup {
        let parts = relativePath.split(separator: "/")
        if parts.count > 1 {
            guard parts[0].lowercased() == "common" else { return .translation }
            return classify(name: String(parts[parts.count - 1]))
        }
        return classify(name: relativePath)
    }

    private static func classify(name: String) -> ZoneGroup {
        let lowered = name.lowercased()
        if lowered.hasSuffix("_patch.ff") { return .patch }
        // Zombies es el objetivo del proyecto: common_zombie.ff también cuenta aquí.
        if lowered.contains("zombie") { return .zombies }
        if lowered.hasPrefix("code_") { return .code }
        if lowered.hasPrefix("ui_") { return .interface }
        if lowered.hasPrefix("common") { return .common }
        if lowered.hasPrefix("mp_") { return .multiplayer }
        if lowered.hasPrefix("frontend") || lowered.hasPrefix("so_narrative") { return .interface }
        return .campaign
    }
}

/// Una zona (`.ff`) encontrada en la carpeta del usuario.
struct ZoneEntry {
    /// Ruta relativa a la carpeta `zone`, con `/` como separador.
    let relativePath: String
    /// Tamaño del archivo comprimido en disco.
    let sizeBytes: Int64
    /// Cabecera de 12 bytes, o nil si no se pudo leer.
    let header: ZoneFileHeader?

    var name: String {
        String(relativePath.split(separator: "/").last ?? Substring(relativePath))
    }

    var group: ZoneGroup { ZoneGroup.classify(relativePath: relativePath) }

    /// true si el archivo tiene el magic y la versión esperados de BO1 (PC).
    var isSupported: Bool {
        guard let header else { return false }
        return header.magicMatches && header.versionIsSupported
    }

    var sizeDescription: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Inventario de las zonas de la carpeta del juego. Solo lee cabeceras y
/// tamaños: no descomprime ni carga contenido del juego (reglas.md, sección 5).
struct ZoneCatalog {
    let entries: [ZoneEntry]

    var totalBytes: Int64 { entries.reduce(0) { $0 + $1.sizeBytes } }
    var totalDescription: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    /// Zonas con magic o versión inesperados (otra versión del juego, archivo corrupto…).
    var unsupported: [ZoneEntry] { entries.filter { !$0.isSupported } }

    var supported: [ZoneEntry] { entries.filter(\.isSupported) }

    /// Zonas de Zombies, que es el objetivo del proyecto.
    var zombies: [ZoneEntry] { entries.filter { $0.group == .zombies } }

    func count(of group: ZoneGroup) -> Int {
        entries.filter { $0.group == group }.count
    }

    func bytes(of group: ZoneGroup) -> Int64 {
        entries.filter { $0.group == group }.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Grupos presentes, en el orden declarado en `ZoneGroup`.
    var presentGroups: [ZoneGroup] {
        ZoneGroup.allCases.filter { count(of: $0) > 0 }
    }

    /// Recorre `zone/` y construye el inventario. Debe llamarse con el acceso de
    /// seguridad ya abierto para URLs de Archivos.
    static func build(in gameFolder: URL, fileManager: FileManager = .default) -> ZoneCatalog {
        let zoneFolder = gameFolder.appendingPathComponent(GameFolderValidator.zoneFolderName, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        var entries: [ZoneEntry] = []

        let enumerator = fileManager.enumerator(
            at: zoneFolder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        )

        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension.lowercased() == "ff" else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            entries.append(
                ZoneEntry(
                    relativePath: relativePath(of: url, in: zoneFolder),
                    sizeBytes: Int64(values.fileSize ?? 0),
                    header: try? ZoneFileHeaderReader.read(from: url)
                )
            )
        }

        entries.sort { $0.relativePath < $1.relativePath }
        return ZoneCatalog(entries: entries)
    }

    private static func relativePath(of url: URL, in base: URL) -> String {
        let basePath = base.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(basePath) else { return url.lastPathComponent }
        var relative = String(path.dropFirst(basePath.count))
        if relative.hasPrefix("/") { relative.removeFirst() }
        return relative
    }
}
