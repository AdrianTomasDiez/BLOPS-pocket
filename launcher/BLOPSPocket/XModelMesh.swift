import Foundation
import Compression
import simd

/// Vértice intermedio sin ambigüedad de alineación entre Swift y Metal (12 Floats = 48 bytes).
struct XModelGPUVertex {
    var px: Float
    var py: Float
    var pz: Float
    var nx: Float
    var ny: Float
    var nz: Float
    var r: Float
    var g: Float
    var b: Float
    var a: Float
    var u: Float
    var v: Float
}

/// Textura RGBA8 decodificada desde un GfxImageLoadDef inline del FastFile.
struct XModelTextureData {
    let name: String
    let width: Int
    let height: Int
    let formatName: String
    let rgbaPixels: [UInt8]
}

/// Resumen ligero de un XModel inline hallado en el stream descomprimido de una zona.
struct XModelSummary: Identifiable, Hashable {
    var id: Int { offset }
    let name: String
    let offset: Int
    let numBones: Int
    let numLods: Int
    let numSurfaces: Int
    let lod0Surfaces: Int
    let lod0Vertices: Int
    let lod0Triangles: Int
    let radius: Float
}

/// Malla 3D intermedia lista para cargar en buffers de Metal (LOD 0 o sector de GFXWORLD).
struct XModelMesh {
    let meshId: String
    let name: String
    let offset: Int
    let numBones: Int
    let numLods: Int
    let surfaceCount: Int
    let mins: SIMD3<Float>
    let maxs: SIMD3<Float>
    let radius: Float
    let vertices: [XModelGPUVertex]
    let indices: [UInt32]
    let topMaterials: [String]
    let texture: XModelTextureData?

    init(
        meshId: String? = nil,
        name: String,
        offset: Int,
        numBones: Int,
        numLods: Int,
        surfaceCount: Int,
        mins: SIMD3<Float>,
        maxs: SIMD3<Float>,
        radius: Float,
        vertices: [XModelGPUVertex],
        indices: [UInt32],
        topMaterials: [String] = [],
        texture: XModelTextureData? = nil
    ) {
        self.meshId = meshId ?? "\(offset):\(name):\(indices.count)"
        self.name = name
        self.offset = offset
        self.numBones = numBones
        self.numLods = numLods
        self.surfaceCount = surfaceCount
        self.mins = mins
        self.maxs = maxs
        self.radius = radius
        self.vertices = vertices
        self.indices = indices
        self.topMaterials = topMaterials
        self.texture = texture
    }

    var vertexCount: Int { vertices.count }
    var triangleCount: Int { indices.count / 3 }
    var center: SIMD3<Float> { (mins + maxs) * 0.5 }
}

enum XModelReaderError: LocalizedError {
    case invalidHeader
    case decompressionFailed
    case modelNotFound(String)
    case truncatedData(String)

    var errorDescription: String? {
        switch self {
        case .invalidHeader:
            return "El archivo no tiene la cabecera IWffu100 (0x1D9) de BO1 PC."
        case .decompressionFailed:
            return "No se pudo descomprimir el stream zlib del FastFile."
        case .modelNotFound(let name):
            return "No se encontró el XModel '\(name)' en esta zona."
        case .truncatedData(let detail):
            return "Datos de geometría truncados o fuera de rango (\(detail))."
        }
    }
}

/// Lector nativo del formato binario XModel / XSurface y GFXWORLD de BO1 PC (T5).
/// Espeja la lógica verificada en `tools/zxmodel.mjs` y `tools/zgfxworld.mjs`.
enum XModelReader {
    private static let headerLen = 12
    private static let following: UInt32 = 0xFFFF_FFFF
    private static let loadDefFollowing: UInt32 = 0xFFFF_FFFE
    private static let streamVertSentinel: UInt32 = 0x0000_FFFF
    private static let xmodelFixedSize = 252
    private static let xsurfaceFixedSize = 68
    private static let packedVertexSize = 32
    private static let gfxWorldFixedSize = 1084
    private static let gfxWorldDrawOffset = 344
    private static let gfxLightGridOffset = 536
    private static let gfxDpvsOffset = 836
    private static let gfxWorldVertexSize = 44
    private static let gfxSurfaceSize = 80

    private static let d3dFmtR5G6B5: Int32 = 23
    private static let d3dFmtG16R16: Int32 = 34
    private static let d3dFmtL8: Int32 = 50
    private static let d3dFmtDXT1: Int32 = 0x3154_5844

    /// Modelos representativos de Zombies para destacar en el selector.
    static let featuredModels: [String] = [
        "zombie_skull",
        "zombie_bomb",
        "zombie_teddybear",
        "zombie_vending_jugg_on",
        "zombie_vending_revive_on",
        "zombie_vending_sleight_on",
        "zombie_vending_doubletap_on",
        "zombie_vending_packapunch_on",
        "zombie_x2_icon",
        "zombie_ammocan",
        "weapon_usa_ray_gun",
        "viewmodel_usa_ray_gun",
        "viewmodel_knife_bowie"
    ]

    /// Descomprime el stream zlib de un archivo `.ff` de BO1 PC.
    static func decompressZone(at url: URL) throws -> Data {
        let raw = try Data(contentsOf: url, options: .mappedIfSafe)
        guard raw.count > headerLen + 6 else {
            throw XModelReaderError.invalidHeader
        }
        let header = try ZoneFileHeaderReader.read(from: url)
        guard header.magicMatches && header.versionIsSupported else {
            throw XModelReaderError.invalidHeader
        }

        let deflateStart = headerLen + 2
        let deflateEnd = raw.count - 4
        if deflateEnd > deflateStart {
            let slice = raw.subdata(in: deflateStart..<deflateEnd) as NSData
            if let inflated = try? slice.decompressed(using: .zlib) as Data, !inflated.isEmpty {
                return inflated
            }
        }
        let fallbackSlice = raw.subdata(in: deflateStart..<raw.count) as NSData
        if let inflated = try? fallbackSlice.decompressed(using: .zlib) as Data, !inflated.isEmpty {
            return inflated
        }
        throw XModelReaderError.decompressionFailed
    }

    /// Escanea el stream descomprimido en busca de todos los XModel inline válidos.
    static func scanModels(in stream: Data) -> [XModelSummary] {
        return stream.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> [XModelSummary] in
            guard buf.count > xmodelFixedSize + 64 else { return [] }
            let startOffset = bodyStartOffset(buf)
            var results: [XModelSummary] = []
            var pos = startOffset
            let limit = buf.count - xmodelFixedSize - 2

            while pos <= limit {
                guard let idx = findNextFollowingMarker(buf, from: pos, limit: limit) else {
                    break
                }
                if isValidXModelHeader(buf, at: idx) {
                    if let summary = decodeSummary(buf, at: idx) {
                        results.append(summary.summary)
                        pos = summary.endOffset
                        continue
                    }
                }
                pos = idx + 1
            }
            return results
        }
    }

    /// Extrae la malla completa del LOD 0 de un XModel a partir de su desplazamiento en el stream.
    static func extractMesh(from stream: Data, at base: Int) throws -> XModelMesh {
        return try stream.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> XModelMesh in
            return try decodeFullMesh(buf, at: base)
        }
    }

    // MARK: - Decodificación interna sin requisitos de alineación

    @inline(__always)
    private static func readU16(_ buf: UnsafeRawBufferPointer, _ offset: Int) -> UInt16 {
        return UInt16(buf[offset]) | (UInt16(buf[offset + 1]) << 8)
    }

    @inline(__always)
    private static func readI16(_ buf: UnsafeRawBufferPointer, _ offset: Int) -> Int16 {
        return Int16(bitPattern: readU16(buf, offset))
    }

    @inline(__always)
    private static func readU32(_ buf: UnsafeRawBufferPointer, _ offset: Int) -> UInt32 {
        let b0 = UInt32(buf[offset])
        let b1 = UInt32(buf[offset + 1]) << 8
        let b2 = UInt32(buf[offset + 2]) << 16
        let b3 = UInt32(buf[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    @inline(__always)
    private static func readI32(_ buf: UnsafeRawBufferPointer, _ offset: Int) -> Int32 {
        return Int32(bitPattern: readU32(buf, offset))
    }

    @inline(__always)
    private static func readF32(_ buf: UnsafeRawBufferPointer, _ offset: Int) -> Float {
        return Float(bitPattern: readU32(buf, offset))
    }

    @inline(__always)
    private static func isFollowing(_ val: UInt32, allowStreamSentinel: Bool = false) -> Bool {
        return val == following || (allowStreamSentinel && val == streamVertSentinel)
    }

    @inline(__always)
    private static func isFolOrInsert(_ val: UInt32) -> Bool {
        return val == following || val == loadDefFollowing
    }

    @inline(__always)
    private static func isValidZonePtr(_ val: UInt32) -> Bool {
        return val == 0 || val == following || val >= 0x8000_0000
    }

    @inline(__always)
    private static func isModelNameChar(_ ch: UInt8) -> Bool {
        return (ch >= 0x30 && ch <= 0x39)
            || (ch >= 0x41 && ch <= 0x5A)
            || (ch >= 0x61 && ch <= 0x7A)
            || ch == 0x5F || ch == 0x2D || ch == 0x2E || ch == 0x2F
    }

    private static func bodyStartOffset(_ buf: UnsafeRawBufferPointer) -> Int {
        guard buf.count >= 52 else { return 0 }
        let stringCount = Int(readU32(buf, 36))
        let stringsPtr = readU32(buf, 40)
        let assetCount = Int(readU32(buf, 44))
        var pos = 52
        if stringCount > 0 && stringsPtr == following {
            pos += stringCount * 4
            guard pos <= buf.count else { return 52 }
            for _ in 0..<stringCount {
                while pos < buf.count && buf[pos] != 0 {
                    pos += 1
                }
                pos += 1
            }
        }
        pos += assetCount * 8
        return min(max(52, pos), buf.count)
    }

    private static func findNextFollowingMarker(_ buf: UnsafeRawBufferPointer, from start: Int, limit: Int) -> Int? {
        var i = start
        while i <= limit {
            if buf[i] == 0xFF && buf[i + 1] == 0xFF && buf[i + 2] == 0xFF && buf[i + 3] == 0xFF {
                return i
            }
            i += 1
        }
        return nil
    }

    private static func isValidXModelHeader(_ buf: UnsafeRawBufferPointer, at base: Int) -> Bool {
        guard base >= 0, base + xmodelFixedSize + 2 <= buf.count else { return false }
        guard readU32(buf, base) == following else { return false }

        let numBones = buf[base + 4]
        let numRootBones = buf[base + 5]
        let numsurfs = buf[base + 6]
        let lodRampType = buf[base + 7]
        if numRootBones > numBones { return false }
        if numsurfs == 0 || numsurfs > 128 { return false }
        if lodRampType > 8 { return false }

        if !isValidZonePtr(readU32(buf, base + 8)) { return false }
        if !isValidZonePtr(readU32(buf, base + 12)) { return false }
        if !isValidZonePtr(readU32(buf, base + 16)) { return false }
        if !isValidZonePtr(readU32(buf, base + 20)) { return false }
        if !isValidZonePtr(readU32(buf, base + 24)) { return false }
        if !isValidZonePtr(readU32(buf, base + 28)) { return false }
        if readU32(buf, base + 32) != following { return false }
        if !isValidZonePtr(readU32(buf, base + 36)) { return false }

        let numLods = readI16(buf, base + 216)
        if numLods < 1 || numLods > 4 { return false }

        let radius = readF32(buf, base + 188)
        if !radius.isFinite || radius < 0 || radius > 1_000_000 { return false }

        let nameStart = base + xmodelFixedSize
        var nul = nameStart
        let maxNul = min(buf.count, nameStart + 129)
        while nul < maxNul && buf[nul] != 0 {
            if !isModelNameChar(buf[nul]) { return false }
            nul += 1
        }
        if nul == nameStart || nul >= maxNul { return false }
        return true
    }

    private static func decodeSummary(_ buf: UnsafeRawBufferPointer, at base: Int) -> (summary: XModelSummary, endOffset: Int)? {
        let numBones = Int(buf[base + 4])
        let numRootBones = Int(buf[base + 5])
        let numsurfs = Int(buf[base + 6])
        let numLods = Int(readI16(buf, base + 216))
        let radius = readF32(buf, base + 188)

        let lod0NumSurfs = min(numsurfs, max(1, Int(readU16(buf, base + 40 + 4))))
        let lod0SurfIndex = Int(readU16(buf, base + 40 + 6))

        var c = base + xmodelFixedSize
        var nameBytes: [UInt8] = []
        while c < buf.count && buf[c] != 0 {
            nameBytes.append(buf[c])
            c += 1
        }
        guard c < buf.count, let name = String(bytes: nameBytes, encoding: .ascii), !name.isEmpty else {
            return nil
        }
        c += 1

        let childBones = max(0, numBones - numRootBones)
        if readU32(buf, base + 8) == following { c += numBones * 2 }
        if readU32(buf, base + 12) == following { c += childBones * 1 }
        if readU32(buf, base + 16) == following { c += childBones * 8 }
        if readU32(buf, base + 20) == following { c += childBones * 16 }
        if readU32(buf, base + 24) == following { c += numBones * 1 }
        if readU32(buf, base + 28) == following { c += numBones * 32 }

        let surfsTable = c
        c += numsurfs * xsurfaceFixedSize
        guard c <= buf.count else { return nil }

        var lod0Verts = 0
        var lod0Tris = 0

        for i in 0..<numsurfs {
            let sb = surfsTable + i * xsurfaceFixedSize
            let vertListCount = Int(buf[sb + 1])
            let vertCount = Int(readU16(buf, sb + 4))
            let triCount = Int(readU16(buf, sb + 6))
            if vertCount <= 0 || triCount <= 0 { return nil }

            let triIndicesPtr = readU32(buf, sb + 12)
            let vc0 = Int(readI16(buf, sb + 16))
            let vc1 = Int(readI16(buf, sb + 18))
            let vc2 = Int(readI16(buf, sb + 20))
            let vc3 = Int(readI16(buf, sb + 22))
            let vertsBlendPtr = readU32(buf, sb + 24)
            let tensionDataPtr = readU32(buf, sb + 28)
            let verts0Ptr = readU32(buf, sb + 32)
            let vertListPtr = readU32(buf, sb + 40)

            if vertsBlendPtr == following {
                c += 2 * max(0, vc0 + 3 * vc1 + 5 * vc2 + 7 * vc3)
            }
            if tensionDataPtr == following {
                c += 48 * max(0, vc0 + vc1 + vc2 + vc3)
            }
            if isFollowing(verts0Ptr, allowStreamSentinel: true) {
                c += vertCount * packedVertexSize
            }
            if vertListPtr == following {
                let vlTable = c
                c += vertListCount * 12
                guard c <= buf.count else { return nil }
                for j in 0..<vertListCount {
                    let vlb = vlTable + j * 12
                    if readU32(buf, vlb + 8) == following {
                        let ctb = c
                        c += 40
                        guard c <= buf.count else { return nil }
                        let nodeCount = Int(readU32(buf, ctb + 24))
                        let nodesPtr = readU32(buf, ctb + 28)
                        let leafCount = Int(readU32(buf, ctb + 32))
                        let leafsPtr = readU32(buf, ctb + 36)
                        if nodesPtr == following { c += nodeCount * 16 }
                        if leafsPtr == following { c += leafCount * 2 }
                    }
                }
            }
            var trisOffset = -1
            if isFollowing(triIndicesPtr, allowStreamSentinel: true) {
                trisOffset = c
                c += triCount * 6
            }
            guard c <= buf.count, trisOffset >= 0 else { return nil }

            for t in 0..<triCount {
                let tp = trisOffset + t * 6
                let i0 = Int(readU16(buf, tp + 0))
                let i1 = Int(readU16(buf, tp + 2))
                let i2 = Int(readU16(buf, tp + 4))
                if i0 >= vertCount || i1 >= vertCount || i2 >= vertCount {
                    return nil
                }
            }

            if i >= lod0SurfIndex && i < lod0SurfIndex + lod0NumSurfs {
                lod0Verts += vertCount
                lod0Tris += triCount
            }
        }

        let summary = XModelSummary(
            name: name,
            offset: base,
            numBones: numBones,
            numLods: numLods,
            numSurfaces: numsurfs,
            lod0Surfaces: lod0NumSurfs,
            lod0Vertices: lod0Verts,
            lod0Triangles: lod0Tris,
            radius: radius
        )
        return (summary, c)
    }

    private static func decodeFullMesh(_ buf: UnsafeRawBufferPointer, at base: Int) throws -> XModelMesh {
        guard isValidXModelHeader(buf, at: base) else {
            throw XModelReaderError.truncatedData("cabecera XModel inválida en \(base)")
        }

        let numBones = Int(buf[base + 4])
        let numRootBones = Int(buf[base + 5])
        let numsurfs = Int(buf[base + 6])
        let numLods = Int(readI16(buf, base + 216))
        let radius = readF32(buf, base + 188)
        let mins = SIMD3<Float>(
            readF32(buf, base + 192),
            readF32(buf, base + 196),
            readF32(buf, base + 200)
        )
        let maxs = SIMD3<Float>(
            readF32(buf, base + 204),
            readF32(buf, base + 208),
            readF32(buf, base + 212)
        )

        let lod0NumSurfs = min(numsurfs, max(1, Int(readU16(buf, base + 40 + 4))))
        let lod0SurfIndex = Int(readU16(buf, base + 40 + 6))

        var c = base + xmodelFixedSize
        var nameBytes: [UInt8] = []
        while c < buf.count && buf[c] != 0 {
            nameBytes.append(buf[c])
            c += 1
        }
        let name = String(bytes: nameBytes, encoding: .ascii) ?? "xmodel"
        c += 1

        let childBones = max(0, numBones - numRootBones)
        if readU32(buf, base + 8) == following { c += numBones * 2 }
        if readU32(buf, base + 12) == following { c += childBones * 1 }
        if readU32(buf, base + 16) == following { c += childBones * 8 }
        if readU32(buf, base + 20) == following { c += childBones * 16 }
        if readU32(buf, base + 24) == following { c += numBones * 1 }
        if readU32(buf, base + 28) == following { c += numBones * 32 }

        let surfsTable = c
        c += numsurfs * xsurfaceFixedSize
        guard c <= buf.count else {
            throw XModelReaderError.truncatedData("tabla XSurface fuera de rango")
        }

        var combinedVertices: [XModelGPUVertex] = []
        var combinedIndices: [UInt32] = []

        for i in 0..<numsurfs {
            let sb = surfsTable + i * xsurfaceFixedSize
            let vertListCount = Int(buf[sb + 1])
            let vertCount = Int(readU16(buf, sb + 4))
            let triCount = Int(readU16(buf, sb + 6))

            let triIndicesPtr = readU32(buf, sb + 12)
            let vc0 = Int(readI16(buf, sb + 16))
            let vc1 = Int(readI16(buf, sb + 18))
            let vc2 = Int(readI16(buf, sb + 20))
            let vc3 = Int(readI16(buf, sb + 22))
            let vertsBlendPtr = readU32(buf, sb + 24)
            let tensionDataPtr = readU32(buf, sb + 28)
            let verts0Ptr = readU32(buf, sb + 32)
            let vertListPtr = readU32(buf, sb + 40)

            if vertsBlendPtr == following {
                c += 2 * max(0, vc0 + 3 * vc1 + 5 * vc2 + 7 * vc3)
            }
            if tensionDataPtr == following {
                c += 48 * max(0, vc0 + vc1 + vc2 + vc3)
            }

            var vertsOffset = -1
            if isFollowing(verts0Ptr, allowStreamSentinel: true) {
                vertsOffset = c
                c += vertCount * packedVertexSize
            }

            if vertListPtr == following {
                let vlTable = c
                c += vertListCount * 12
                guard c <= buf.count else {
                    throw XModelReaderError.truncatedData("vertList fuera de rango")
                }
                for j in 0..<vertListCount {
                    let vlb = vlTable + j * 12
                    if readU32(buf, vlb + 8) == following {
                        let ctb = c
                        c += 40
                        guard c <= buf.count else {
                            throw XModelReaderError.truncatedData("collisionTree fuera de rango")
                        }
                        let nodeCount = Int(readU32(buf, ctb + 24))
                        let nodesPtr = readU32(buf, ctb + 28)
                        let leafCount = Int(readU32(buf, ctb + 32))
                        let leafsPtr = readU32(buf, ctb + 36)
                        if nodesPtr == following { c += nodeCount * 16 }
                        if leafsPtr == following { c += leafCount * 2 }
                    }
                }
            }

            var trisOffset = -1
            if isFollowing(triIndicesPtr, allowStreamSentinel: true) {
                trisOffset = c
                c += triCount * 6
            }
            guard c <= buf.count else {
                throw XModelReaderError.truncatedData("superficie \(i) fuera de rango")
            }

            let isLod0 = i >= lod0SurfIndex && i < lod0SurfIndex + lod0NumSurfs
            guard isLod0, vertsOffset >= 0, trisOffset >= 0 else { continue }

            let baseVertex = UInt32(combinedVertices.count)
            combinedVertices.reserveCapacity(combinedVertices.count + vertCount)
            for v in 0..<vertCount {
                let vp = vertsOffset + v * packedVertexSize
                let px = readF32(buf, vp + 0)
                let py = readF32(buf, vp + 4)
                let pz = readF32(buf, vp + 8)

                let r = Float(buf[vp + 16]) / 255.0
                let g = Float(buf[vp + 17]) / 255.0
                let b = Float(buf[vp + 18]) / 255.0
                let a = Float(buf[vp + 19]) / 255.0

                let rawTc = readU32(buf, vp + 20)
                let u = unpackHalfFloat(UInt16((rawTc >> 16) & 0xFFFF))
                let vCoord = unpackHalfFloat(UInt16(rawTc & 0xFFFF))

                let nScale = (Float(buf[vp + 27]) + 192.0) / 32385.0
                let nx = (Float(buf[vp + 24]) - 127.0) * nScale
                let ny = (Float(buf[vp + 25]) - 127.0) * nScale
                let nz = (Float(buf[vp + 26]) - 127.0) * nScale

                combinedVertices.append(
                    XModelGPUVertex(
                        px: px, py: py, pz: pz,
                        nx: nx, ny: ny, nz: nz,
                        r: r, g: g, b: b, a: a,
                        u: u, v: vCoord
                    )
                )
            }

            combinedIndices.reserveCapacity(combinedIndices.count + triCount * 3)
            for t in 0..<triCount {
                let tp = trisOffset + t * 6
                let i0 = UInt32(readU16(buf, tp + 0))
                let i1 = UInt32(readU16(buf, tp + 2))
                let i2 = UInt32(readU16(buf, tp + 4))
                if i0 < UInt32(vertCount) && i1 < UInt32(vertCount) && i2 < UInt32(vertCount) {
                    combinedIndices.append(baseVertex + i0)
                    combinedIndices.append(baseVertex + i1)
                    combinedIndices.append(baseVertex + i2)
                }
            }
        }

        return XModelMesh(
            meshId: "xmodel:\(base)",
            name: name,
            offset: base,
            numBones: numBones,
            numLods: numLods,
            surfaceCount: lod0NumSurfs,
            mins: mins,
            maxs: maxs,
            radius: max(radius, 1.0),
            vertices: combinedVertices,
            indices: combinedIndices
        )
    }

    // MARK: - Reconstrucción espacial de GFXWORLD, materiales y texturas (Fase 6c.2)

    struct GfxWorldSectorInfo: Identifiable, Hashable {
        var id: Int { chunkIndex }
        let chunkIndex: Int
        let name: String
        let subtitle: String
        let cellIndices: [Int]
        let includeBrushModels: Bool
        let maxCoordBounds: Float?
        let surfaceCount: Int
        let triangleCount: Int
    }

    private struct GfxCellDescriptor {
        let index: Int
        let mins: SIMD3<Float>
        let maxs: SIMD3<Float>
        let surfaceCount: Int
        let startSurfIndex: Int
    }

    private struct GfxInlineImage {
        let name: String
        let width: Int
        let height: Int
        let format: Int32
        let dataStart: Int
        let resourceSize: Int
        let next: Int
    }

    private struct GfxWorldLayout {
        let baseOffset: Int
        let surfaceCount: Int
        let staticSurfaceCount: Int
        let smodelCount: Int
        let vertexCount: Int
        let indexCount: Int
        let vStart: Int
        let iStart: Int
        let cells: [GfxCellDescriptor]
        let materials: [String]
        let sortedSurfIndexStart: Int
        let smodelInstsStart: Int
        let surfacesStart: Int
        let smodelDrawInstsStart: Int
        let lightmapSecondary: GfxInlineImage?
        let lightmapSecondaryB: GfxInlineImage?
        let reflectionProbe1: GfxInlineImage?
        let outdoorImage: GfxInlineImage?
    }

    struct GfxStaticModelPlacement {
        let index: Int
        let cullDist: Float
        let origin: SIMD3<Float>
        let axis0: SIMD3<Float>
        let axis1: SIMD3<Float>
        let axis2: SIMD3<Float>
        let scale: Float
        let modelPtr: UInt32
        let assetIndex: Int
    }

    private struct KinoRoomSpec {
        let index: Int
        let name: String
        let subtitle: String
        let cells: [Int]
        let includeBrushModels: Bool
        let maxCoordBounds: Float?
    }

    private static let kinoRoomSpecs: [KinoRoomSpec] = [
        KinoRoomSpec(
            index: 0,
            name: "1. Sala Inicial y Balcones (Lobby)",
            subtitle: "Celdas PVS 15–19 · Teleporter principal y escaleras",
            cells: [15, 16, 17, 18, 19],
            includeBrushModels: false,
            maxCoordBounds: nil
        ),
        KinoRoomSpec(
            index: 1,
            name: "2. Vestíbulo Central y Comedor (Foyer)",
            subtitle: "Celda PVS 6 · Galería superior e inferior central",
            cells: [6],
            includeBrushModels: false,
            maxCoordBounds: nil
        ),
        KinoRoomSpec(
            index: 2,
            name: "3. Auditorio Principal y Escenario",
            subtitle: "Celdas PVS 1, 2 y 7 · Patio de butacas, telón y escenario",
            cells: [1, 2, 7],
            includeBrushModels: false,
            maxCoordBounds: nil
        ),
        KinoRoomSpec(
            index: 3,
            name: "4. Ala Este: Camerinos y Sala Superior",
            subtitle: "Celdas PVS 3–4, 8–14 · Sala MP40 y vestuario",
            cells: [3, 4, 8, 9, 10, 11, 12, 13, 14],
            includeBrushModels: false,
            maxCoordBounds: nil
        ),
        KinoRoomSpec(
            index: 4,
            name: "5. Callejón Trasero Este (Double Tap)",
            subtitle: "Celdas PVS 5, 26 y 27 · Salida lateral trasera",
            cells: [5, 26, 27],
            includeBrushModels: false,
            maxCoordBounds: nil
        ),
        KinoRoomSpec(
            index: 5,
            name: "6. Ala Oeste: Crematorio y Trampa Fuego",
            subtitle: "Celdas PVS 20–23 · Sala caldera y pasillo oeste",
            cells: [20, 21, 22, 23],
            includeBrushModels: false,
            maxCoordBounds: nil
        ),
        KinoRoomSpec(
            index: 6,
            name: "7. Patio Exterior y Tejados",
            subtitle: "Celdas PVS 0, 24–25, 28–32 · Fachadas y callejón",
            cells: [0, 24, 25, 28, 29, 30, 31, 32],
            includeBrushModels: false,
            maxCoordBounds: 3200
        ),
        KinoRoomSpec(
            index: 7,
            name: "8. Puertas, Barricadas y Modelos BSP",
            subtitle: "Superficies dinámicas 8289–9140 (BrushModels)",
            cells: [],
            includeBrushModels: true,
            maxCoordBounds: nil
        ),
        KinoRoomSpec(
            index: 8,
            name: "9. Mapa Interior Completo (Salas 1–6 + Puertas)",
            subtitle: "Recorrido continuo de todo el teatro interior",
            cells: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 26, 27],
            includeBrushModels: true,
            maxCoordBounds: nil
        )
    ]

    /// Escanea si la zona contiene un asset GFXWORLD y devuelve las salas espaciales reales.
    static func scanWorldSectors(in stream: Data) -> [GfxWorldSectorInfo] {
        return stream.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> [GfxWorldSectorInfo] in
            guard let layout = parseGfxWorldLayout(buf) else { return [] }
            let minMatPtr = computeMinMaterialPtr(buf, layout: layout)

            return kinoRoomSpecs.map { spec in
                let surfaceIds = collectSurfaceIndices(
                    buf,
                    layout: layout,
                    cellIndices: spec.cells,
                    includeBrushModels: spec.includeBrushModels
                )
                var keptSurfaces = 0
                var totalTris = 0
                for s in surfaceIds {
                    let se = layout.surfacesStart + s * gfxSurfaceSize
                    if let maxB = spec.maxCoordBounds {
                        let minX = abs(readF32(buf, se + 0))
                        let minY = abs(readF32(buf, se + 4))
                        let maxX = abs(readF32(buf, se + 16))
                        let maxY = abs(readF32(buf, se + 20))
                        if minX > maxB || minY > maxB || maxX > maxB || maxY > maxB { continue }
                    }
                    let matPtr = readU32(buf, se + 48)
                    let matIdx = minMatPtr < UInt32.max && matPtr >= minMatPtr ? Int((matPtr - minMatPtr) / 8) : -1
                    let matName = (matIdx >= 0 && matIdx < layout.materials.count) ? layout.materials[matIdx] : ""
                    let style = classifyMaterialColor(matName)
                    if style.skip { continue }
                    let triCount = Int(readU16(buf, se + 34))
                    keptSurfaces += 1
                    totalTris += triCount
                }
                return GfxWorldSectorInfo(
                    chunkIndex: spec.index,
                    name: spec.name,
                    subtitle: spec.subtitle,
                    cellIndices: spec.cells,
                    includeBrushModels: spec.includeBrushModels,
                    maxCoordBounds: spec.maxCoordBounds,
                    surfaceCount: keptSurfaces,
                    triangleCount: totalTris
                )
            }
        }
    }

    /// Extrae una sala o una combinación acumulada de salas de GFXWORLD con materiales y textura real.
    static func extractWorldSectors(
        from stream: Data,
        sectorIndices: [Int],
        maxTriangles: Int = 95_000
    ) throws -> XModelMesh {
        let sortedIndices = Array(Set(sectorIndices)).sorted()
        guard !sortedIndices.isEmpty else {
            throw XModelReaderError.truncatedData("No se seleccionó ninguna sala del mapa")
        }

        return try stream.withUnsafeBytes { (buf: UnsafeRawBufferPointer) -> XModelMesh in
            guard let layout = parseGfxWorldLayout(buf) else {
                throw XModelReaderError.truncatedData("No se encontró el asset GFXWORLD o sus tablas dpvs::surfaces")
            }

            let minMatPtr = computeMinMaterialPtr(buf, layout: layout)
            var allCells: [Int] = []
            var includeBrush = false
            var coordLimit: Float? = nil

            for idx in sortedIndices {
                guard idx >= 0 && idx < kinoRoomSpecs.count else { continue }
                let spec = kinoRoomSpecs[idx]
                allCells.append(contentsOf: spec.cells)
                if spec.includeBrushModels { includeBrush = true }
                if sortedIndices.count == 1 { coordLimit = spec.maxCoordBounds }
            }

            let surfaceIds = collectSurfaceIndices(
                buf,
                layout: layout,
                cellIndices: allCells,
                includeBrushModels: includeBrush
            )

            // Contar total de triángulos para aplicar submuestreo determinista solo si se combinan muchas salas
            var totalCandidateTris = 0
            for s in surfaceIds {
                let se = layout.surfacesStart + s * gfxSurfaceSize
                totalCandidateTris += Int(readU16(buf, se + 34))
            }
            let triStep = totalCandidateTris > maxTriangles ? max(1, (totalCandidateTris + maxTriangles - 1) / maxTriangles) : 1

            var usedVerts: [Int: UInt32] = [:]
            usedVerts.reserveCapacity(min(totalCandidateTris * 2, 120_000))
            var combinedVertices: [XModelGPUVertex] = []
            combinedVertices.reserveCapacity(min(totalCandidateTris * 2, 120_000))
            var combinedIndices: [UInt32] = []
            combinedIndices.reserveCapacity(min(totalCandidateTris * 3, maxTriangles * 3))
            var materialTris: [String: Int] = [:]
            var keptSurfaces = 0
            var minP = SIMD3<Float>(repeating: .infinity)
            var maxP = SIMD3<Float>(repeating: -.infinity)

            for s in surfaceIds {
                let se = layout.surfacesStart + s * gfxSurfaceSize
                if let maxB = coordLimit {
                    let minX = abs(readF32(buf, se + 0))
                    let minY = abs(readF32(buf, se + 4))
                    let maxX = abs(readF32(buf, se + 16))
                    let maxY = abs(readF32(buf, se + 20))
                    if minX > maxB || minY > maxB || maxX > maxB || maxY > maxB { continue }
                }

                let firstVertex = Int(readI32(buf, se + 28))
                let surfVertCount = Int(readU16(buf, se + 32))
                let triCount = Int(readU16(buf, se + 34))
                let baseIndex = Int(readI32(buf, se + 36))
                let matPtr = readU32(buf, se + 48)
                let lightmapIndex = buf[se + 52]

                let matIdx = minMatPtr < UInt32.max && matPtr >= minMatPtr ? Int((matPtr - minMatPtr) / 8) : -1
                let matName = (matIdx >= 0 && matIdx < layout.materials.count) ? layout.materials[matIdx] : "mat_\(matIdx)"
                let style = classifyMaterialColor(matName)
                if style.skip { continue }

                if firstVertex < 0 || firstVertex + surfVertCount > layout.vertexCount { continue }
                if baseIndex < 0 || baseIndex + triCount * 3 > layout.indexCount { continue }

                keptSurfaces += 1
                materialTris[matName, default: 0] += triCount

                var t = 0
                while t < triCount {
                    defer { t += triStep }
                    if combinedIndices.count / 3 >= maxTriangles { break }

                    let idxOff = layout.iStart + (baseIndex + t * 3) * 2
                    let l0 = Int(readU16(buf, idxOff + 0))
                    let l1 = Int(readU16(buf, idxOff + 2))
                    let l2 = Int(readU16(buf, idxOff + 4))
                    if l0 == l1 || l1 == l2 || l2 == l0 { continue }
                    if l0 >= surfVertCount || l1 >= surfVertCount || l2 >= surfVertCount { continue }

                    let g0 = firstVertex + l0
                    let g1 = firstVertex + l1
                    let g2 = firstVertex + l2

                    for gIdx in [g0, g1, g2] {
                        let vertKey = gIdx &* 1024 &+ max(0, matIdx)
                        if let existing = usedVerts[vertKey] {
                            combinedIndices.append(existing)
                        } else {
                            let vp = layout.vStart + gIdx * gfxWorldVertexSize
                            let px = readF32(buf, vp + 0)
                            let py = readF32(buf, vp + 4)
                            let pz = readF32(buf, vp + 8)

                            let vr = Float(buf[vp + 16]) / 255.0
                            let vg = Float(buf[vp + 17]) / 255.0
                            let vb = Float(buf[vp + 18]) / 255.0
                            let va = Float(buf[vp + 19]) / 255.0

                            // Color semántico del material modulado por el GfxColor por vértice
                            let r = style.rgb.x * (0.55 + 0.45 * vr)
                            let g = style.rgb.y * (0.55 + 0.45 * vg)
                            let b = style.rgb.z * (0.55 + 0.45 * vb)

                            let texU = readF32(buf, vp + 20)
                            let texV = readF32(buf, vp + 24)
                            let lmapU = readF32(buf, vp + 28)
                            let lmapV = readF32(buf, vp + 32)
                            let hasLmap = (lightmapIndex == 0 || lightmapIndex == 1)
                                && lmapU >= 0.0 && lmapU <= 1.0
                                && lmapV >= 0.0 && lmapV <= 1.0
                            let u = hasLmap ? lmapU : (texU - floor(texU))
                            let vCoord = hasLmap ? lmapV : (texV - floor(texV))

                            let nScale = (Float(buf[vp + 39]) + 192.0) / 32385.0
                            let nx = (Float(buf[vp + 36]) - 127.0) * nScale
                            let ny = (Float(buf[vp + 37]) - 127.0) * nScale
                            let nz = (Float(buf[vp + 38]) - 127.0) * nScale

                            minP.x = min(minP.x, px)
                            minP.y = min(minP.y, py)
                            minP.z = min(minP.z, pz)
                            maxP.x = max(maxP.x, px)
                            maxP.y = max(maxP.y, py)
                            maxP.z = max(maxP.z, pz)

                            let newIdx = UInt32(combinedVertices.count)
                            usedVerts[vertKey] = newIdx
                            combinedVertices.append(
                                XModelGPUVertex(
                                    px: px, py: py, pz: pz,
                                    nx: nx, ny: ny, nz: nz,
                                    r: r, g: g, b: b, a: va,
                                    u: u, v: vCoord
                                )
                            )
                            combinedIndices.append(newIdx)
                        }
                    }
                }
            }

            // 3. Extraer e integrar instancias de modelos estáticos (dpvs::smodelDrawInsts) de la sala
            if layout.smodelDrawInstsStart > 0 && layout.smodelCount > 0 && minP.x.isFinite && maxP.x.isFinite {
                let pad: Float = 75.0
                let roomMin = minP - SIMD3<Float>(pad, pad, pad)
                let roomMax = maxP + SIMD3<Float>(pad, pad, pad)

                // Índice de XModels inline: mapear assetIndex de XAssetList al offset de scanModels
                let assetCount = Int(readU32(buf, 44))
                var xmodelOffsetsByAsset: [Int: Int] = [:]
                if assetCount > 0 && assetCount < 5000 {
                    let inlineModels = scanModels(in: stream)
                    var inlineIdx = 0
                    for a in 0..<assetCount {
                        let aOff = 17135 + a * 8
                        guard aOff + 8 <= buf.count else { break }
                        let aType = readI32(buf, aOff)
                        let aHdr = readU32(buf, aOff + 4)
                        if aType == 5 && aHdr == following {
                            if inlineIdx < inlineModels.count {
                                xmodelOffsetsByAsset[a] = inlineModels[inlineIdx].offset
                                inlineIdx += 1
                            }
                        }
                    }
                }

                var cachedMeshes: [Int: XModelMesh] = [:]
                var addedProps = 0
                let maxProps = 120

                for i in 0..<layout.smodelCount {
                    if addedProps >= maxProps || combinedIndices.count / 3 >= maxTriangles { break }
                    let off = layout.smodelDrawInstsStart + i * 76
                    guard off + 76 <= buf.count else { break }

                    let ox = readF32(buf, off + 4)
                    let oy = readF32(buf, off + 8)
                    let oz = readF32(buf, off + 12)
                    let origin = SIMD3<Float>(ox, oy, oz)

                    if origin.x < roomMin.x || origin.x > roomMax.x ||
                        origin.y < roomMin.y || origin.y > roomMax.y ||
                        origin.z < roomMin.z || origin.z > roomMax.z {
                        continue
                    }

                    let a0 = SIMD3<Float>(readF32(buf, off + 16), readF32(buf, off + 20), readF32(buf, off + 24))
                    let a1 = SIMD3<Float>(readF32(buf, off + 28), readF32(buf, off + 32), readF32(buf, off + 36))
                    let a2 = SIMD3<Float>(readF32(buf, off + 40), readF32(buf, off + 44), readF32(buf, off + 48))
                    let scale = readF32(buf, off + 52)
                    let modelPtr = readU32(buf, off + 56)

                    let vAddr = Int(modelPtr & 0x1FFFFFFF)
                    let assetIndex = (vAddr - 17137) / 8
                    guard let modelOffset = xmodelOffsetsByAsset[assetIndex] else { continue }

                    let propMesh: XModelMesh
                    if let cached = cachedMeshes[modelOffset] {
                        propMesh = cached
                    } else if let decoded = try? decodeFullMesh(buf, at: modelOffset) {
                        cachedMeshes[modelOffset] = decoded
                        propMesh = decoded
                    } else {
                        continue
                    }

                    if (combinedIndices.count + propMesh.indices.count) / 3 > maxTriangles {
                        break
                    }

                    addedProps += 1
                    let baseVertexOffset = UInt32(combinedVertices.count)

                    for vert in propMesh.vertices {
                        let mx = vert.px
                        let my = vert.py
                        let mz = vert.pz

                        let wx = origin.x + scale * (mx * a0.x + my * a1.x + mz * a2.x)
                        let wy = origin.y + scale * (mx * a0.y + my * a1.y + mz * a2.y)
                        let wz = origin.z + scale * (mx * a0.z + my * a1.z + mz * a2.z)

                        let nx = vert.nx * a0.x + vert.ny * a1.x + vert.nz * a2.x
                        let ny = vert.nx * a0.y + vert.ny * a1.y + vert.nz * a2.y
                        let nz = vert.nx * a0.z + vert.ny * a1.z + vert.nz * a2.z
                        let nLen = sqrt(nx * nx + ny * ny + nz * nz)
                        let invN = nLen > 0.0001 ? (1.0 / nLen) : 1.0

                        combinedVertices.append(
                            XModelGPUVertex(
                                px: wx, py: wy, pz: wz,
                                nx: nx * invN, ny: ny * invN, nz: nz * invN,
                                r: vert.r * 0.95, g: vert.g * 0.95, b: vert.b * 0.95, a: vert.a,
                                u: vert.u, v: vert.v
                            )
                        )
                    }

                    for idx in propMesh.indices {
                        combinedIndices.append(baseVertexOffset + idx)
                    }
                }
            }

            let topMats = materialTris
                .sorted { $0.value > $1.value }
                .prefix(6)
                .map { "\($0.key) (\($0.value)t)" }

            let inlineTexture = decodeWorldTexture(buf, layout: layout)
            let span = maxP - minP
            let radius = combinedVertices.isEmpty ? 100.0 : max(length(span) * 0.5, 1.0)

            let title: String
            if sortedIndices.count == 1, let first = sortedIndices.first, first < kinoRoomSpecs.count {
                title = kinoRoomSpecs[first].name
            } else {
                title = "Kino der Toten (\(sortedIndices.count) salas combinadas)"
            }

            let keyStr = sortedIndices.map(String.init).joined(separator: "+")
            return XModelMesh(
                meshId: "gfxworld:\(layout.baseOffset):rooms:\(keyStr)",
                name: title,
                offset: layout.baseOffset + (sortedIndices.first ?? 0) + 1,
                numBones: 0,
                numLods: 1,
                surfaceCount: keptSurfaces,
                mins: minP,
                maxs: maxP,
                radius: radius,
                vertices: combinedVertices,
                indices: combinedIndices,
                topMaterials: topMats,
                texture: inlineTexture
            )
        }
    }

    static func extractWorldSector(from stream: Data, chunkIndex: Int = 0) throws -> XModelMesh {
        return try extractWorldSectors(from: stream, sectorIndices: [chunkIndex])
    }

    // MARK: - Clasificación semántica de materiales y decodificación de texturas inline

    private static func classifyMaterialColor(_ name: String) -> (skip: Bool, rgb: SIMD3<Float>) {
        let n = name.lowercased()
        if n.contains("sky") || n.contains("caulk") || n.contains("portal") || n.contains("shadow") || n.contains("clip") {
            return (true, SIMD3<Float>(0.5, 0.5, 0.5))
        }
        if n.contains("curtain") || n.contains("velvet") || n.contains("carpet") || n.contains("drape") || n.contains("seat") {
            return (false, SIMD3<Float>(0.70, 0.20, 0.18))
        }
        if n.contains("wood") || n.contains("parquet") || n.contains("plank") || n.contains("door") || n.contains("chair") || n.contains("bench") {
            return (false, SIMD3<Float>(0.64, 0.44, 0.27))
        }
        if n.contains("brick") || n.contains("cobble") || n.contains("tile") || n.contains("roof") || n.contains("marble") {
            return (false, SIMD3<Float>(0.65, 0.50, 0.40))
        }
        if n.contains("metal") || n.contains("iron") || n.contains("steel") || n.contains("pipe") || n.contains("duct") || n.contains("cage") || n.contains("teleport") {
            return (false, SIMD3<Float>(0.47, 0.52, 0.58))
        }
        if n.contains("glass") || n.contains("window") || n.contains("mirror") {
            return (false, SIMD3<Float>(0.56, 0.74, 0.84))
        }
        if n.contains("foliage") || n.contains("tree") || n.contains("ivy") || n.contains("grass") {
            return (false, SIMD3<Float>(0.36, 0.53, 0.32))
        }
        if n.contains("ter_") || n.contains("dirt") || n.contains("mud") || n.contains("rubble") || n.contains("trash") || n.contains("ash") {
            return (false, SIMD3<Float>(0.49, 0.45, 0.39))
        }
        if n.contains("plaster") || n.contains("wallpaper") || n.contains("stucco") || n.contains("trim") || n.contains("ceiling") {
            return (false, SIMD3<Float>(0.79, 0.74, 0.65))
        }
        if n.contains("concrete") || n.contains("cement") || n.contains("asphalt") || n.contains("floor") || n.contains("wall") {
            return (false, SIMD3<Float>(0.67, 0.66, 0.63))
        }
        return (false, SIMD3<Float>(0.73, 0.71, 0.67))
    }

    /// Decodifica una textura real inline de GFXWORLD (combinando *lightmap0_secondary R5G6B5 +
    /// *lightmap0_secondaryb G16R16, o bien *reflection_probe1 DXT1).
    private static func decodeWorldTexture(_ buf: UnsafeRawBufferPointer, layout: GfxWorldLayout) -> XModelTextureData? {
        if let sec = layout.lightmapSecondary,
           let secB = layout.lightmapSecondaryB,
           sec.format == d3dFmtR5G6B5,
           secB.format == d3dFmtG16R16,
           sec.dataStart + sec.resourceSize <= buf.count,
           secB.dataStart + secB.resourceSize <= buf.count {
            let outW = 256
            let outH = 512
            let srcW = max(1, secB.width)
            let srcH = max(1, secB.height)
            var rgba = [UInt8](repeating: 255, count: outW * outH * 4)

            for y in 0..<outH {
                let sy = (y * srcH) / outH
                for x in 0..<outW {
                    let sx = (x * srcW) / outW
                    let pxIdx = sy * srcW + sx
                    let offS = sec.dataStart + pxIdx * 2
                    let offB = secB.dataStart + pxIdx * 4

                    let c16 = readU16(buf, offS)
                    let r5 = Float((c16 >> 11) & 0x1F) / 31.0
                    let g6 = Float((c16 >> 5) & 0x3F) / 63.0
                    let b5 = Float(c16 & 0x1F) / 31.0

                    let r16 = Float(readU16(buf, offB))
                    let g16 = Float(readU16(buf, offB + 2))
                    let hdr = min(1.35, max(0.45, ((r16 + g16) * 0.5) / 680.0))

                    // Combinar crominancia R5G6B5 e intensidad G16R16 del lightmap real horneado
                    let rf = min(255.0, max(35.0, (0.45 + 0.55 * r5) * hdr * 235.0))
                    let gf = min(255.0, max(35.0, (0.40 + 0.60 * g6) * hdr * 225.0))
                    let bf = min(255.0, max(35.0, (0.45 + 0.55 * b5) * hdr * 235.0))

                    let dst = (y * outW + x) * 4
                    rgba[dst + 0] = UInt8(rf)
                    rgba[dst + 1] = UInt8(gf)
                    rgba[dst + 2] = UInt8(bf)
                    rgba[dst + 3] = 255
                }
            }
            return XModelTextureData(
                name: "\(sec.name) + \(secB.name)",
                width: outW,
                height: outH,
                formatName: "R5G6B5+G16R16",
                rgbaPixels: rgba
            )
        }

        if let probe = layout.reflectionProbe1,
           probe.format == d3dFmtDXT1,
           probe.dataStart + probe.resourceSize <= buf.count {
            let w = max(4, probe.width)
            let h = max(4, probe.height)
            let blocksX = max(1, (w + 3) / 4)
            var rgba = [UInt8](repeating: 255, count: w * h * 4)

            for y in 0..<h {
                let by = y >> 2
                let py = y & 3
                for x in 0..<w {
                    let bx = x >> 2
                    let px = x & 3
                    let bOff = probe.dataStart + (by * blocksX + bx) * 8
                    guard bOff + 8 <= probe.dataStart + probe.resourceSize else { continue }
                    let c0 = readU16(buf, bOff)
                    let c1 = readU16(buf, bOff + 2)
                    let lut = readU32(buf, bOff + 4)

                    let r0 = Int((c0 >> 11) & 0x1F) * 255 / 31
                    let g0 = Int((c0 >> 5) & 0x3F) * 255 / 63
                    let b0 = Int(c0 & 0x1F) * 255 / 31
                    let r1 = Int((c1 >> 11) & 0x1F) * 255 / 31
                    let g1 = Int((c1 >> 5) & 0x3F) * 255 / 63
                    let b1 = Int(c1 & 0x1F) * 255 / 31

                    let code = (lut >> UInt32((py * 4 + px) * 2)) & 3
                    let r: Int
                    let g: Int
                    let b: Int
                    switch code {
                    case 0: (r, g, b) = (r0, g0, b0)
                    case 1: (r, g, b) = (r1, g1, b1)
                    case 2:
                        r = c0 > c1 ? (2 * r0 + r1) / 3 : (r0 + r1) / 2
                        g = c0 > c1 ? (2 * g0 + g1) / 3 : (g0 + g1) / 2
                        b = c0 > c1 ? (2 * b0 + b1) / 3 : (b0 + b1) / 2
                    default:
                        r = c0 > c1 ? (r0 + 2 * r1) / 3 : 0
                        g = c0 > c1 ? (g0 + 2 * g1) / 3 : 0
                        b = c0 > c1 ? (b0 + 2 * b1) / 3 : 0
                    }
                    let dst = (y * w + x) * 4
                    rgba[dst + 0] = UInt8(clamping: r)
                    rgba[dst + 1] = UInt8(clamping: g)
                    rgba[dst + 2] = UInt8(clamping: b)
                    rgba[dst + 3] = 255
                }
            }
            return XModelTextureData(
                name: probe.name,
                width: w,
                height: h,
                formatName: "DXT1",
                rgbaPixels: rgba
            )
        }

        return nil
    }

    private static func computeMinMaterialPtr(_ buf: UnsafeRawBufferPointer, layout: GfxWorldLayout) -> UInt32 {
        var minPtr: UInt32 = .max
        for s in 0..<layout.surfaceCount {
            let ptr = readU32(buf, layout.surfacesStart + s * gfxSurfaceSize + 48)
            if ptr > 0 && ptr < minPtr {
                minPtr = ptr
            }
        }
        return minPtr
    }

    private static func collectSurfaceIndices(
        _ buf: UnsafeRawBufferPointer,
        layout: GfxWorldLayout,
        cellIndices: [Int],
        includeBrushModels: Bool
    ) -> [Int] {
        var result: [Int] = []
        var seen = Set<Int>()

        for cIdx in cellIndices {
            guard cIdx >= 0 && cIdx < layout.cells.count else { continue }
            let cell = layout.cells[cIdx]
            for k in 0..<cell.surfaceCount {
                let pos = layout.sortedSurfIndexStart + (cell.startSurfIndex + k) * 2
                guard pos + 2 <= buf.count else { break }
                let s = Int(readU16(buf, pos))
                if s >= 0 && s < layout.surfaceCount && !seen.contains(s) {
                    seen.insert(s)
                    result.append(s)
                }
            }
        }

        if includeBrushModels {
            for s in layout.staticSurfaceCount..<layout.surfaceCount {
                if !seen.contains(s) {
                    seen.insert(s)
                    result.append(s)
                }
            }
        }
        return result
    }

    // MARK: - Recorrido determinista de GfxWorld en el stream descomprimido

    private static func skipCString(_ buf: UnsafeRawBufferPointer, from pos: Int) -> Int {
        var i = pos
        while i < buf.count && buf[i] != 0 {
            i += 1
        }
        return min(buf.count, i + 1)
    }

    private static func readCString(_ buf: UnsafeRawBufferPointer, from pos: Int) -> (text: String, next: Int) {
        var i = pos
        var bytes: [UInt8] = []
        while i < buf.count && buf[i] != 0 {
            bytes.append(buf[i])
            i += 1
        }
        let str = String(bytes: bytes, encoding: .isoLatin1) ?? ""
        return (str, min(buf.count, i + 1))
    }

    private static func readGfxInlineImage(_ buf: UnsafeRawBufferPointer, at pos: Int) -> GfxInlineImage {
        let texPtr = readU32(buf, pos)
        let width = Int(readU16(buf, pos + 20))
        let height = Int(readU16(buf, pos + 22))
        let namePtr = readU32(buf, pos + 44)
        var c = pos + 52
        var name = ""
        if namePtr == following {
            let parsed = readCString(buf, from: c)
            name = parsed.text
            c = parsed.next
        }
        var format: Int32 = 0
        var resourceSize = 0
        var dataStart = -1
        if isFolOrInsert(texPtr) {
            format = readI32(buf, c + 4)
            resourceSize = max(0, Int(readI32(buf, c + 8)))
            dataStart = c + 12
            c += 12 + resourceSize
        }
        return GfxInlineImage(
            name: name,
            width: width,
            height: height,
            format: format,
            dataStart: dataStart,
            resourceSize: resourceSize,
            next: c
        )
    }

    private static func parseGfxWorldLayout(_ buf: UnsafeRawBufferPointer) -> GfxWorldLayout? {
        guard buf.count > gfxWorldFixedSize + 1024 else { return nil }
        let limit = buf.count - gfxWorldFixedSize
        var foundBase: Int?

        for pos in 0..<limit {
            let drawBase = pos + gfxWorldDrawOffset
            if readU32(buf, drawBase + 160) == following && readU32(buf, drawBase + 188) == following {
                let vc = Int(readU32(buf, drawBase + 156))
                let ic = Int(readI32(buf, drawBase + 184))
                if vc > 0 && vc < 2_000_000 && ic > 0 && ic < 5_000_000 {
                    let minX = readF32(buf, pos + 600)
                    let maxX = readF32(buf, pos + 612)
                    if minX.isFinite && maxX.isFinite && maxX > minX {
                        foundBase = pos
                        break
                    }
                }
            }
        }

        guard let base = foundBase else { return nil }
        let drawBase = base + gfxWorldDrawOffset
        let lightGridBase = base + gfxLightGridOffset
        let dpvsBase = base + gfxDpvsOffset

        let surfaceCount = Int(readI32(buf, base + 16))
        let cellCount = Int(readI32(buf, base + 320))
        let reflectionProbeCount = Int(readU32(buf, drawBase + 0))
        let lightmapCount = Int(readI32(buf, drawBase + 12))
        let vertexCount = Int(readU32(buf, drawBase + 156))
        let vertexLayerDataSize = Int(readU32(buf, drawBase + 168))
        let indexCount = Int(readI32(buf, drawBase + 184))
        let modelCount = Int(readI32(buf, base + 592))
        let materialMemoryCount = Int(readI32(buf, base + 628))
        let smodelCount = Int(readU32(buf, dpvsBase + 0))
        let staticSurfaceCount = Int(readU32(buf, dpvsBase + 8))

        var c = base + gfxWorldFixedSize
        if readU32(buf, base + 0) == following { c = skipCString(buf, from: c) }
        if readU32(buf, base + 4) == following { c = skipCString(buf, from: c) }
        if readU32(buf, base + 24) == following { c += Int(readI32(buf, base + 20)) * 32 }
        if readU32(buf, base + 32) == following { c += Int(readI32(buf, base + 28)) * 4 }
        if readU32(buf, base + 40) == following { c += Int(readI32(buf, base + 36)) * 4 }
        if isFolOrInsert(readU32(buf, base + 44)) { c = readGfxInlineImage(buf, at: c).next }
        if readU32(buf, base + 52) == following { c = skipCString(buf, from: c) }
        if readU32(buf, base + 236) == following {
            let defPtr = readU32(buf, c + 352)
            c += 368
            if defPtr == following {
                let ldName = readU32(buf, c)
                let ldImg = readU32(buf, c + 4)
                c += 16
                if ldName == following { c = skipCString(buf, from: c) }
                if isFolOrInsert(ldImg) { c = readGfxInlineImage(buf, at: c).next }
            }
        }
        if readU32(buf, base + 268) == following { c += Int(readU32(buf, base + 264)) * 32 }
        if readU32(buf, base + 276) == following { c += Int(readU32(buf, base + 272)) * 16 }
        if readU32(buf, base + 284) == following { c += Int(readU32(buf, base + 280)) * 16 }
        if readU32(buf, base + 292) == following { c += Int(readU32(buf, base + 288)) * 24 }
        if readU32(buf, base + 300) == following { c += Int(readU32(buf, base + 296)) * 16 }
        if readU32(buf, base + 324) == following { c += Int(readI32(buf, base + 8)) * 20 }
        if readU32(buf, base + 328) == following { c += Int(readI32(buf, base + 12)) * 2 }

        var cells: [GfxCellDescriptor] = []
        if readU32(buf, base + 340) == following && cellCount > 0 {
            let cellsStart = c
            c += cellCount * 56
            for i in 0..<cellCount {
                let ce = cellsStart + i * 56
                let mins = SIMD3<Float>(readF32(buf, ce), readF32(buf, ce + 4), readF32(buf, ce + 8))
                let maxs = SIMD3<Float>(readF32(buf, ce + 12), readF32(buf, ce + 16), readF32(buf, ce + 20))
                let aabbTreeCount = Int(readI32(buf, ce + 24))
                let aabbTreePtr = readU32(buf, ce + 28)
                let portalCount = Int(readI32(buf, ce + 32))
                let portalsPtr = readU32(buf, ce + 36)
                let cullGroupCount = Int(readI32(buf, ce + 40))
                let cullGroupsPtr = readU32(buf, ce + 44)
                let refProbeCount = Int(buf[ce + 48])
                let refProbesPtr = readU32(buf, ce + 52)

                var rootSurfCount = 0
                var rootStartSurfIndex = 0
                if aabbTreePtr == following {
                    let treeStart = c
                    rootSurfCount = Int(readU16(buf, treeStart + 26))
                    rootStartSurfIndex = Int(readU16(buf, treeStart + 28))
                    c += aabbTreeCount * 40
                    for t in 0..<aabbTreeCount {
                        let te = treeStart + t * 40
                        if readU32(buf, te + 32) == following {
                            c += Int(readU16(buf, te + 30)) * 2
                        }
                    }
                }
                if portalsPtr == following {
                    let portStart = c
                    c += portalCount * 68
                    for p in 0..<portalCount {
                        let pe = portStart + p * 68
                        if readU32(buf, pe + 36) == following {
                            c += Int(buf[pe + 40]) * 12
                        }
                    }
                }
                if cullGroupsPtr == following { c += cullGroupCount * 4 }
                if refProbesPtr == following { c += refProbeCount }
                cells.append(
                    GfxCellDescriptor(
                        index: i,
                        mins: mins,
                        maxs: maxs,
                        surfaceCount: rootSurfCount,
                        startSurfIndex: rootStartSurfIndex
                    )
                )
            }
        }

        var reflectionProbe1: GfxInlineImage?
        if readU32(buf, drawBase + 4) == following && reflectionProbeCount > 0 {
            let rpStart = c
            c += reflectionProbeCount * 24
            for i in 0..<reflectionProbeCount {
                let rpe = rpStart + i * 24
                let imgPtr = readU32(buf, rpe + 12)
                let volPtr = readU32(buf, rpe + 16)
                let volCount = Int(readU32(buf, rpe + 20))
                if isFolOrInsert(imgPtr) {
                    let img = readGfxInlineImage(buf, at: c)
                    if img.resourceSize > 1024 { reflectionProbe1 = img }
                    c = img.next
                }
                if volPtr == following {
                    let vs = c
                    c += volCount * 68
                    for v in 0..<volCount {
                        let ve = vs + v * 68
                        if readU32(buf, ve + 64) == following {
                            c += Int(readU16(buf, ve + 60)) * 2
                        }
                    }
                }
            }
        }

        var lightmapSecondary: GfxInlineImage?
        var lightmapSecondaryB: GfxInlineImage?
        if readU32(buf, drawBase + 16) == following && lightmapCount > 0 {
            let lmStart = c
            c += lightmapCount * 12
            for i in 0..<lightmapCount {
                let lme = lmStart + i * 12
                let p0 = readU32(buf, lme + 0)
                let p1 = readU32(buf, lme + 4)
                let p2 = readU32(buf, lme + 8)
                if isFolOrInsert(p0) { c = readGfxInlineImage(buf, at: c).next }
                if isFolOrInsert(p1) {
                    let img = readGfxInlineImage(buf, at: c)
                    if i == 0 { lightmapSecondary = img }
                    c = img.next
                }
                if isFolOrInsert(p2) {
                    let img = readGfxInlineImage(buf, at: c)
                    if i == 0 { lightmapSecondaryB = img }
                    c = img.next
                }
            }
        }

        for i in 0..<31 {
            let p = readU32(buf, drawBase + 32 + i * 4)
            if isFolOrInsert(p) { c = readGfxInlineImage(buf, at: c).next }
        }

        let vStart = c
        c += vertexCount * gfxWorldVertexSize
        if readU32(buf, drawBase + 172) == following { c += vertexLayerDataSize }
        let iStart = c
        c += indexCount * 2

        if readU32(buf, lightGridBase + 28) == following {
            let rowAxis = Int(readU32(buf, lightGridBase + 20))
            let minRow = Int(readU16(buf, lightGridBase + 8 + rowAxis * 2))
            let maxRow = Int(readU16(buf, lightGridBase + 14 + rowAxis * 2))
            c += (maxRow - minRow + 1) * 2
        }
        if readU32(buf, lightGridBase + 36) == following { c += Int(readU32(buf, lightGridBase + 32)) }
        if readU32(buf, lightGridBase + 44) == following { c += Int(readU32(buf, lightGridBase + 40)) * 4 }
        if readU32(buf, lightGridBase + 52) == following { c += Int(readU32(buf, lightGridBase + 48)) * 168 }

        if readU32(buf, base + 596) == following { c += modelCount * 60 }

        var materials: [String] = []
        if readU32(buf, base + 632) == following && materialMemoryCount > 0 {
            let matMemStart = c
            c += materialMemoryCount * 8
            materials.reserveCapacity(materialMemoryCount)
            for i in 0..<materialMemoryCount {
                let mp = readU32(buf, matMemStart + i * 8)
                if isFolOrInsert(mp) {
                    let mBase = c
                    c += 192
                    var name = ""
                    if readU32(buf, mBase) == following {
                        let parsed = readCString(buf, from: c)
                        name = parsed.text
                        c = parsed.next
                    }
                    let texCount = Int(buf[mBase + 170])
                    let constCount = Int(buf[mBase + 171])
                    let sbCount = Int(buf[mBase + 172])
                    let ttPtr = readU32(buf, mBase + 180)
                    let ctPtr = readU32(buf, mBase + 184)
                    let sbPtr = readU32(buf, mBase + 188)
                    if isFolOrInsert(ttPtr) {
                        let ttStart = c
                        c += texCount * 16
                        for j in 0..<texCount {
                            let sem = buf[ttStart + j * 16 + 7]
                            let uPtr = readU32(buf, ttStart + j * 16 + 12)
                            if sem != 11 && isFolOrInsert(uPtr) {
                                c = readGfxInlineImage(buf, at: c).next
                            }
                        }
                    }
                    if isFolOrInsert(ctPtr) { c += constCount * 32 }
                    if isFolOrInsert(sbPtr) { c += sbCount * 8 }
                    materials.append(name)
                } else {
                    materials.append("mat_\(i)")
                }
            }
        }

        for sunMatOff in [base + 640, base + 644] {
            let sp = readU32(buf, sunMatOff)
            if isFolOrInsert(sp) {
                let mBase = c
                c += 192
                if readU32(buf, mBase) == following { c = skipCString(buf, from: c) }
                let texCount = Int(buf[mBase + 170])
                let constCount = Int(buf[mBase + 171])
                let sbCount = Int(buf[mBase + 172])
                let ttPtr = readU32(buf, mBase + 180)
                let ctPtr = readU32(buf, mBase + 184)
                let sbPtr = readU32(buf, mBase + 188)
                if isFolOrInsert(ttPtr) {
                    let ttStart = c
                    c += texCount * 16
                    for j in 0..<texCount {
                        let uPtr = readU32(buf, ttStart + j * 16 + 12)
                        if buf[ttStart + j * 16 + 7] != 11 && isFolOrInsert(uPtr) {
                            c = readGfxInlineImage(buf, at: c).next
                        }
                    }
                }
                if isFolOrInsert(ctPtr) { c += constCount * 32 }
                if isFolOrInsert(sbPtr) { c += sbCount * 8 }
            }
        }

        var outdoorImage: GfxInlineImage?
        if isFolOrInsert(readU32(buf, base + 796)) {
            let img = readGfxInlineImage(buf, at: c)
            outdoorImage = img
            c = img.next
        }

        let primaryLightCount = Int(readU32(buf, base + 256))
        if readU32(buf, base + 828) == following {
            let sgStart = c
            c += primaryLightCount * 12
            for i in 0..<primaryLightCount {
                let sge = sgStart + i * 12
                if readU32(buf, sge + 4) == following { c += Int(readU16(buf, sge + 0)) * 2 }
                if readU32(buf, sge + 8) == following { c += Int(readU16(buf, sge + 2)) * 2 }
            }
        }
        if readU32(buf, base + 832) == following {
            let lrStart = c
            c += primaryLightCount * 8
            for i in 0..<primaryLightCount {
                let lre = lrStart + i * 8
                let hullCount = Int(readU32(buf, lre + 0))
                if readU32(buf, lre + 4) == following {
                    let hStart = c
                    c += hullCount * 80
                    for h in 0..<hullCount {
                        let he = hStart + h * 80
                        if readU32(buf, he + 76) == following {
                            c += Int(readU32(buf, he + 72)) * 20
                        }
                    }
                }
            }
        }

        let sortedSurfIndexStart = readU32(buf, dpvsBase + 80) == following ? c : -1
        if sortedSurfIndexStart != -1 { c += staticSurfaceCount * 2 }
        let smodelInstsStart = readU32(buf, dpvsBase + 84) == following ? c : -1
        if smodelInstsStart != -1 { c += smodelCount * 40 }
        let surfacesStart = readU32(buf, dpvsBase + 88) == following ? c : -1
        if surfacesStart != -1 { c += surfaceCount * gfxSurfaceSize }
        let smodelDrawInstsStart = readU32(buf, dpvsBase + 96) == following ? c : -1

        guard sortedSurfIndexStart > 0,
              surfacesStart > 0,
              surfacesStart + surfaceCount * gfxSurfaceSize <= buf.count else {
            return nil
        }

        return GfxWorldLayout(
            baseOffset: base,
            surfaceCount: surfaceCount,
            staticSurfaceCount: staticSurfaceCount,
            smodelCount: smodelCount,
            vertexCount: vertexCount,
            indexCount: indexCount,
            vStart: vStart,
            iStart: iStart,
            cells: cells,
            materials: materials,
            sortedSurfIndexStart: sortedSurfIndexStart,
            smodelInstsStart: smodelInstsStart,
            surfacesStart: surfacesStart,
            smodelDrawInstsStart: smodelDrawInstsStart,
            lightmapSecondary: lightmapSecondary,
            lightmapSecondaryB: lightmapSecondaryB,
            reflectionProbe1: reflectionProbe1,
            outdoorImage: outdoorImage
        )
    }

    private static func unpackHalfFloat(_ u16: UInt16) -> Float {
        let sign: Float = (u16 & 0x8000) != 0 ? -1.0 : 1.0
        let exp = Int((u16 & 0x7C00) >> 10)
        let frac = Float(u16 & 0x03FF)
        if exp == 0 {
            return sign * pow(2.0, -14.0) * (frac / 1024.0)
        }
        if exp == 0x1F {
            return 0.0
        }
        return sign * pow(2.0, Float(exp - 15)) * (1.0 + frac / 1024.0)
    }
}
