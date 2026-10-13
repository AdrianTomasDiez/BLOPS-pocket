import Foundation

/// Cabecera de un FastFile (`.ff`) de Call of Duty: Black Ops 1 en PC.
///
/// Formato verificado sobre la copia del usuario (reglas.md, sección 3.5): los
/// 8 primeros bytes son el magic ASCII `IWffu100`, los 4 siguientes la versión
/// de zona como uint32 little-endian (`0x1D9`, 473, en las 143 zonas medidas) y
/// a partir del byte 12 viene un stream zlib que llega hasta el final del
/// archivo. Leer esta cabecera no descomprime nada.
struct ZoneFileHeader: Equatable {
    /// Magic de los FastFile de BO1 (PC).
    static let magic = "IWffu100"
    /// Versión de zona de BO1 en PC (`0x1D9`).
    static let pcVersion: UInt32 = 0x1D9
    /// Bytes que ocupa la cabecera: 8 de magic + 4 de versión.
    static let byteCount = 12

    let magic: String
    let version: UInt32

    var magicMatches: Bool { magic == Self.magic }
    var versionIsSupported: Bool { version == Self.pcVersion }

    /// Texto de la versión para diagnóstico, sin inventar nombres de juego.
    var versionDescription: String { "0x\(String(version, radix: 16).uppercased())" }
}

enum ZoneFileHeaderError: Error {
    /// El archivo es más corto que la cabecera (12 bytes).
    case truncated
}

enum ZoneFileHeaderReader {
    /// Lee solo los 12 primeros bytes del archivo: nunca descomprime ni carga
    /// el resto (reglas.md, regla 5 sobre memoria).
    static func read(from url: URL) throws -> ZoneFileHeader {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        guard let data = try handle.read(upToCount: ZoneFileHeader.byteCount),
              data.count >= ZoneFileHeader.byteCount else {
            throw ZoneFileHeaderError.truncated
        }

        // Los .ff son little-endian; lo leemos byte a byte para no depender del
        // orden de bytes del dispositivo.
        let version = UInt32(data[8])
            | UInt32(data[9]) << 8
            | UInt32(data[10]) << 16
            | UInt32(data[11]) << 24

        return ZoneFileHeader(
            magic: String(decoding: data.prefix(8), as: UTF8.self),
            version: version
        )
    }
}
