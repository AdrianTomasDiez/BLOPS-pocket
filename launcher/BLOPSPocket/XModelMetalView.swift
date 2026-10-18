import SwiftUI
import Metal
import MetalKit
import simd
import GameController

/// Modo de sombreado para el visor Metal de XModel y GFXWORLD.
enum XModelShadingMode: Int, CaseIterable, Identifiable {
    case directional = 0
    case textured = 1
    case normals = 2
    case unlit = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .directional: return "Luz + Mat"
        case .textured: return "Textura FF"
        case .normals: return "Normales"
        case .unlit: return "Sin luz"
        }
    }
}

/// Modo de cámara para el visor 3D de Metal.
enum CameraMode: String, CaseIterable, Identifiable {
    case orbital = "Orbital"
    case fps = "1ª Persona"

    var id: String { rawValue }
}

/// Uniformes enviados al vertex/fragment shader (2 matrices 4x4 + vector de estado = 144 bytes).
private struct XModelUniforms {
    var mvpMatrix: simd_float4x4
    var modelMatrix: simd_float4x4
    var modeFlags: SIMD4<Float>
}

private let xmodelMetalShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    packed_float3 position;
    packed_float3 normal;
    packed_float4 color;
    packed_float2 uv;
};

struct Uniforms {
    float4x4 mvpMatrix;
    float4x4 modelMatrix;
    float4 modeFlags;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float4 color;
    float2 uv;
    float mode;
    float hasTex;
    float isWorld;
};

vertex VertexOut xmodel_vertex(
    uint vid [[vertex_id]],
    device const VertexIn *vertices [[buffer(0)]],
    constant Uniforms &uniforms [[buffer(1)]]
) {
    VertexIn in = vertices[vid];
    VertexOut out;
    float3 pos = float3(in.position);
    float3 nrm = float3(in.normal);
    out.position = uniforms.mvpMatrix * float4(pos, 1.0);
    out.worldNormal = normalize((uniforms.modelMatrix * float4(nrm, 0.0)).xyz);
    out.color = float4(in.color);
    out.uv = float2(in.uv);
    out.mode = uniforms.modeFlags.x;
    out.hasTex = uniforms.modeFlags.y;
    out.isWorld = uniforms.modeFlags.z;
    return out;
}

fragment float4 xmodel_fragment(
    VertexOut in [[stage_in]],
    texture2d<float> baseTex [[texture(0)]],
    sampler texSampler [[sampler(0)]]
) {
    float3 N = normalize(in.worldNormal);
    if (in.mode > 1.5 && in.mode < 2.5) {
        return float4(N * 0.5 + 0.5, 1.0);
    }

    float3 baseColor = (in.isWorld > 0.5)
        ? in.color.rgb
        : mix(float3(0.82, 0.80, 0.75), in.color.rgb, 0.35);

    float2 wrappedUV = fract(in.uv);
    float3 texRGB = (in.hasTex > 0.5) ? baseTex.sample(texSampler, wrappedUV).rgb : float3(1.0);

    // ModoSinLuz (3)
    if (in.mode >= 2.5) {
        return float4(baseColor, 1.0);
    }

    // Iluminación direccional principal + relleno hemisférico (Z-up en BO1)
    float3 L1 = normalize(float3(0.55, -0.65, 0.52));
    float3 L2 = normalize(float3(-0.45, 0.50, -0.30));
    float diff1 = max(dot(N, L1), 0.0);
    float diff2 = max(dot(N, L2), 0.0) * 0.35;
    float hemi = (N.z * 0.5 + 0.5) * 0.28 + 0.18;
    float lightFactor = hemi + diff1 * 0.75 + diff2;

    // Modo Textura FF (1): resalta la textura real GfxImageLoadDef extraída del FastFile
    if (in.mode > 0.5 && in.mode < 1.5) {
        float3 combined = (in.hasTex > 0.5)
            ? mix(texRGB, baseColor * texRGB * 1.35, 0.55) * (0.45 + 0.55 * lightFactor)
            : baseColor * lightFactor;
        return float4(clamp(combined, 0.0, 1.0), 1.0);
    }

    // Modo Luz + Material (0): color semántico del material + modulación de lightmap real
    float3 modTex = (in.hasTex > 0.5) ? mix(float3(1.0), texRGB * 1.15, 0.35) : float3(1.0);
    float3 lit = baseColor * modTex * lightFactor;
    return float4(clamp(lit, 0.0, 1.0), 1.0);
}
"""

/// Renderizador Metal (`MTKViewDelegate`) para dibujar una malla `XModelMesh`.
final class XModelMetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let samplerState: MTLSamplerState?
    private let fallbackTexture: MTLTexture?

    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var activeTexture: MTLTexture?
    private var hasCustomTexture: Bool = false
    private var isWorldGeometry: Bool = false
    private var indexCount: Int = 0
    private var meshCenter = SIMD3<Float>(0, 0, 0)
    private var meshRadius: Float = 25.0

    var yaw: Float = 0.6
    var pitch: Float = 0.25
    var zoom: Float = 1.0
    var autoRotate: Bool = true
    var wireframe: Bool = false
    var shadingMode: XModelShadingMode = .directional
    var cameraMode: CameraMode = .orbital
    var fpsPosition = SIMD3<Float>(0, 0, 0)

    init?(mtkView: MTKView) {
        guard let dev = mtkView.device ?? MTLCreateSystemDefaultDevice(),
              let queue = dev.makeCommandQueue() else {
            return nil
        }
        self.device = dev
        self.commandQueue = queue
        mtkView.device = dev
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.clearColor = MTLClearColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1.0)
        mtkView.preferredFramesPerSecond = 60

        guard let library = try? dev.makeLibrary(source: xmodelMetalShaderSource, options: nil),
              let vFunc = library.makeFunction(name: "xmodel_vertex"),
              let fFunc = library.makeFunction(name: "xmodel_fragment") else {
            return nil
        }

        let pipeDesc = MTLRenderPipelineDescriptor()
        pipeDesc.vertexFunction = vFunc
        pipeDesc.fragmentFunction = fFunc
        pipeDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipeDesc.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        guard let pso = try? dev.makeRenderPipelineState(descriptor: pipeDesc) else {
            return nil
        }
        self.pipelineState = pso

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        guard let dso = dev.makeDepthStencilState(descriptor: depthDesc) else {
            return nil
        }
        self.depthState = dso

        let sampDesc = MTLSamplerDescriptor()
        sampDesc.minFilter = .linear
        sampDesc.magFilter = .linear
        sampDesc.sAddressMode = .repeat
        sampDesc.tAddressMode = .repeat
        self.samplerState = dev.makeSamplerState(descriptor: sampDesc)

        let texDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        texDesc.usage = [.shaderRead]
        if let tex = dev.makeTexture(descriptor: texDesc) {
            var white: [UInt8] = [255, 255, 255, 255]
            tex.replace(
                region: MTLRegionMake2D(0, 0, 1, 1),
                mipmapLevel: 0,
                withBytes: &white,
                bytesPerRow: 4
            )
            self.fallbackTexture = tex
        } else {
            self.fallbackTexture = nil
        }

        super.init()
    }

    func upload(mesh: XModelMesh) {
        meshCenter = mesh.center
        meshRadius = max(mesh.radius, 1.0)
        isWorldGeometry = mesh.meshId.hasPrefix("gfxworld:")

        if !mesh.vertices.isEmpty {
            vertexBuffer = mesh.vertices.withUnsafeBytes { raw in
                guard let baseAddress = raw.baseAddress else { return nil }
                return device.makeBuffer(bytes: baseAddress, length: raw.count, options: .storageModeShared)
            }
        } else {
            vertexBuffer = nil
        }

        if !mesh.indices.isEmpty {
            indexBuffer = mesh.indices.withUnsafeBytes { raw in
                guard let baseAddress = raw.baseAddress else { return nil }
                return device.makeBuffer(bytes: baseAddress, length: raw.count, options: .storageModeShared)
            }
            indexCount = mesh.indices.count
        } else {
            indexBuffer = nil
            indexCount = 0
        }

        if let texData = mesh.texture,
           texData.width > 0,
           texData.height > 0,
           texData.rgbaPixels.count >= texData.width * texData.height * 4 {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm,
                width: texData.width,
                height: texData.height,
                mipmapped: false
            )
            desc.usage = [.shaderRead]
            if let mtlTex = device.makeTexture(descriptor: desc) {
                texData.rgbaPixels.withUnsafeBytes { raw in
                    if let baseAddress = raw.baseAddress {
                        mtlTex.replace(
                            region: MTLRegionMake2D(0, 0, texData.width, texData.height),
                            mipmapLevel: 0,
                            withBytes: baseAddress,
                            bytesPerRow: texData.width * 4
                        )
                    }
                }
                activeTexture = mtlTex
                hasCustomTexture = true
            } else {
                activeTexture = nil
                hasCustomTexture = false
            }
        } else {
            activeTexture = nil
            hasCustomTexture = false
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let passDesc = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else {
            return
        }

        if autoRotate && cameraMode == .orbital {
            yaw += 0.010
        }

        if let vBuf = vertexBuffer, let iBuf = indexBuffer, indexCount > 0 {
            let size = view.drawableSize
            let aspect = size.height > 0 ? Float(size.width / size.height) : 1.0

            let proj: simd_float4x4
            let viewMat: simd_float4x4

            if cameraMode == .fps {
                proj = Self.perspective(fovYRadians: 65.0 * .pi / 180.0, aspect: aspect, nearZ: 4.0, farZ: 10000.0)
                viewMat = Self.rotationX(pitch - .pi * 0.5)
                    * Self.rotationZ(yaw)
                    * Self.translation(-fpsPosition.x, -fpsPosition.y, -fpsPosition.z)
            } else {
                let dist = max(meshRadius * 2.15 / max(zoom, 0.2), 1.5)
                let nearZ = max(dist * 0.01, 0.5)
                let farZ = max(dist * 12.0, 4000.0)

                proj = Self.perspective(fovYRadians: .pi / 4.0, aspect: aspect, nearZ: nearZ, farZ: farZ)
                viewMat = Self.translation(0, 0, -dist)
                    * Self.rotationX(pitch - .pi * 0.5)
                    * Self.rotationZ(yaw)
                    * Self.translation(-meshCenter.x, -meshCenter.y, -meshCenter.z)
            }

            var uniforms = XModelUniforms(
                mvpMatrix: proj * viewMat,
                modelMatrix: matrix_identity_float4x4,
                modeFlags: SIMD4<Float>(
                    Float(shadingMode.rawValue),
                    hasCustomTexture ? 1.0 : 0.0,
                    isWorldGeometry ? 1.0 : 0.0,
                    0
                )
            )

            encoder.setRenderPipelineState(pipelineState)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)
            encoder.setTriangleFillMode(wireframe ? .lines : .fill)
            encoder.setVertexBuffer(vBuf, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<XModelUniforms>.stride, index: 1)
            if let tex = activeTexture ?? fallbackTexture {
                encoder.setFragmentTexture(tex, index: 0)
            }
            if let smp = samplerState {
                encoder.setFragmentSamplerState(smp, index: 0)
            }
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: indexCount,
                indexType: .uint32,
                indexBuffer: iBuf,
                indexBufferOffset: 0
            )
        }

        encoder.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    // MARK: - Matrices de cámara (convención Metal NDC z en 0...1, modelo Z-up de BO1)

    private static func perspective(fovYRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
        let yScale = 1.0 / tan(fovYRadians * 0.5)
        let xScale = yScale / max(aspect, 0.001)
        let zRange = farZ - nearZ
        let zScale = -(farZ) / zRange
        let wzScale = -(farZ * nearZ) / zRange

        return simd_float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, wzScale, 0)
        ))
    }

    private static func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
        return simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        ))
    }

    private static func rotationX(_ angle: Float) -> simd_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        return simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, c, s, 0),
            SIMD4<Float>(0, -s, c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }

    private static func rotationZ(_ angle: Float) -> simd_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        return simd_float4x4(columns: (
            SIMD4<Float>(c, s, 0, 0),
            SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}

/// Envoltorio SwiftUI de `MTKView` para visualizar un `XModelMesh`.
struct XModelMetalSurfaceView: UIViewRepresentable {
    let mesh: XModelMesh
    @Binding var yaw: Float
    @Binding var pitch: Float
    @Binding var zoom: Float
    @Binding var autoRotate: Bool
    @Binding var wireframe: Bool
    @Binding var shadingMode: XModelShadingMode
    @Binding var cameraMode: CameraMode
    @Binding var fpsPosition: SIMD3<Float>

    final class Coordinator {
        var renderer: XModelMetalRenderer?
        var loadedMeshId: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView(frame: .zero)
        if let renderer = XModelMetalRenderer(mtkView: mtkView) {
            mtkView.delegate = renderer
            renderer.upload(mesh: mesh)
            context.coordinator.renderer = renderer
            context.coordinator.loadedMeshId = mesh.meshId
        }
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        if context.coordinator.loadedMeshId != mesh.meshId {
            renderer.upload(mesh: mesh)
            context.coordinator.loadedMeshId = mesh.meshId
        }
        if !autoRotate || cameraMode == .fps {
            renderer.yaw = yaw
        }
        renderer.pitch = pitch
        renderer.zoom = zoom
        renderer.autoRotate = (cameraMode == .fps) ? false : autoRotate
        renderer.wireframe = wireframe
        renderer.shadingMode = shadingMode
        renderer.cameraMode = cameraMode
        renderer.fpsPosition = fpsPosition
    }
}

/// Pantalla de inspección 3D para explorar los XModel y el mapa real de una zona `.ff`.
struct ZoneXModelInspectorView: View {
    let gameFolder: URL
    let entry: ZoneEntry

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var isExtractingSector = false
    @State private var errorMessage: String?
    @State private var decompressedStream: Data?
    @State private var models: [XModelSummary] = []
    @State private var selectedSummary: XModelSummary?
    @State private var currentMesh: XModelMesh?
    @State private var searchText = ""

    @State private var yaw: Float = 0.6
    @State private var pitch: Float = 0.35
    @State private var zoom: Float = 1.0
    @State private var autoRotate = true
    @State private var wireframe = false
    @State private var shadingMode: XModelShadingMode = .directional
    @State private var cameraMode: CameraMode = .orbital
    @State private var fpsPosition = SIMD3<Float>(0, 0, 0)
    @State private var fpsSpeed: Float = 250.0
    @State private var fpsWalkMode: Bool = true

    // MARK: - Estado de Gameplay Zombies (M1911, Enemigos, Puntos, Rondas y HUD)
    @State private var points: Int = 500
    @State private var roundNumber: Int = 1
    @State private var ammoClip: Int = 8
    @State private var ammoStock: Int = 32
    @State private var isReloading: Bool = false
    @State private var playerHealth: Float = 100.0
    @State private var showHitmarker: Bool = false
    @State private var showDamageFlash: Bool = false
    @State private var weaponRecoil: CGFloat = 0.0
    @State private var showMuzzleFlash: Bool = false

    // Estado del Zombie objetivo en Kino der Toten
    @State private var zombiePosition = SIMD3<Float>(120.0, -550.0, 0.0)
    @State private var zombieHealth: Int = 150
    @State private var isZombieAlive: Bool = true
    @State private var zombieHitTimer: Double = 0.0
    @State private var lastGameTick: Date = Date()
    @State private var gameTimer: Timer? = nil

    enum InspectorMode: String, CaseIterable, Identifiable {
        case models = "Modelos 3D"
        case map = "Mapa (Kino der Toten)"

        var id: String { rawValue }
    }

    @State private var inspectorMode: InspectorMode = .models
    @State private var worldSectors: [XModelReader.GfxWorldSectorInfo] = []
    @State private var selectedSectorIndex: Int = 0
    @State private var accumulateSectors: Bool = false
    @State private var accumulatedSectors: Set<Int> = [0]

    private var featuredInZone: [XModelSummary] {
        let map = Dictionary(uniqueKeysWithValues: models.map { ($0.name, $0) })
        return XModelReader.featuredModels.compactMap { map[$0] }
    }

    private var filteredModels: [XModelSummary] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return models }
        return models.filter { $0.name.lowercased().contains(trimmed) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Descomprimiendo \(entry.name) y escaneando geometría…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text("No se pudo abrir el visor 3D")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if models.isEmpty && worldSectors.isEmpty {
                    VStack(spacing: 10) {
                        Text("Esta zona no contiene XModels ni geometría de mapa.")
                            .font(.headline)
                        Text("Prueba con common_zombie.ff (184 modelos) o zombie_theater.ff (242 modelos y mapa Kino).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    viewerSection

                    if !worldSectors.isEmpty {
                        Picker("Modo de inspección", selection: $inspectorMode) {
                            ForEach(InspectorMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .onChange(of: inspectorMode) { newMode in
                            if newMode == .map {
                                loadActiveMapSelection()
                            } else if let sel = selectedSummary {
                                selectModel(sel)
                            }
                        }
                    }

                    if inspectorMode == .map {
                        mapSectorListSection
                    } else {
                        modelListSection
                    }
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        stopGameLoop()
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadZoneModels()
            startGameLoop()
        }
        .onDisappear {
            stopGameLoop()
        }
    }

    @ViewBuilder
    private var viewerSection: some View {
        VStack(spacing: 6) {
            if let mesh = currentMesh {
                ZStack(alignment: .topLeading) {
                    XModelMetalSurfaceView(
                        mesh: mesh,
                        yaw: $yaw,
                        pitch: $pitch,
                        zoom: $zoom,
                        autoRotate: $autoRotate,
                        wireframe: $wireframe,
                        shadingMode: $shadingMode,
                        cameraMode: $cameraMode,
                        fpsPosition: $fpsPosition
                    )
                    .frame(height: 290)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if cameraMode == .orbital {
                                    autoRotate = false
                                }
                                yaw += Float(value.translation.width) * 0.008
                                let nextPitch = pitch + Float(value.translation.height) * 0.008
                                pitch = min(max(nextPitch, -1.35), 1.35)
                            }
                    )

                    // Capa HUD de Juego de Zombies en 1ª Persona
                    if cameraMode == .fps {
                        fpsGameplayHUD
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(mesh.name)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            if isExtractingSector {
                                ProgressView()
                                    .scaleEffect(0.65)
                            }
                        }
                        Text("\(mesh.vertexCount) vértices · \(mesh.triangleCount) triángulos · \(mesh.surfaceCount) sup")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.88))
                        if cameraMode == .fps {
                            HStack(spacing: 6) {
                                Text("FPS: (\(Int(fpsPosition.x)), \(Int(fpsPosition.y)), \(Int(fpsPosition.z))) · Mirada: \(Int(pitch * 180 / .pi))°")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundColor(.cyan)
                                if isGamepadConnected {
                                    HStack(spacing: 3) {
                                        Image(systemName: "gamecontroller.fill")
                                            .font(.system(size: 9))
                                        Text(gamepadName.isEmpty ? "Mando conectado" : gamepadName)
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundColor(.green)
                                }
                            }
                        } else if let tex = mesh.texture {
                            Text("Tex FF: \(tex.name) (\(tex.width)×\(tex.height) \(tex.formatName))")
                                .font(.caption2)
                                .foregroundColor(.green.opacity(0.95))
                        }
                        if !mesh.topMaterials.isEmpty {
                            Text("Mat: \(mesh.topMaterials.prefix(2).joined(separator: " · "))")
                                .font(.caption2)
                                .foregroundColor(.orange.opacity(0.95))
                                .lineLimit(1)
                        }
                    }
                    .padding(7)
                    .background(Color.black.opacity(0.60))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(8)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                HStack(spacing: 8) {
                    Picker("Cámara", selection: $cameraMode) {
                        ForEach(CameraMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: cameraMode) { mode in
                        if mode == .fps {
                            autoRotate = false
                            if fpsPosition == .zero {
                                resetFPSSpawn()
                            }
                        }
                    }

                    Picker("Sombreado", selection: $shadingMode) {
                        ForEach(XModelShadingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Malla", isOn: $wireframe)
                        .labelsHidden()
                    Text("Malla")
                        .font(.caption2)
                }
                .padding(.horizontal, 12)

                if cameraMode == .fps {
                    fpsControlPanel
                } else {
                    orbitalControlPanel
                }
            }
        }
    }

    /// HUD de juego de Call of Duty Zombies en pantalla completa sobre el viewport Metal
    @ViewBuilder
    private var fpsGameplayHUD: some View {
        ZStack {
            // Flash de daño rojo en bordes cuando el jugador recibe daño
            if showDamageFlash {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.85), lineWidth: 14)
                    .allowsHitTesting(false)
            }

            // Marcador de daño / Hitmarker central
            if showHitmarker {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.red)
                    .shadow(color: .black, radius: 2)
                    .allowsHitTesting(false)
            } else {
                // Crosshair FPS clásico estilo CoD
                ZStack {
                    Rectangle().frame(width: 1.5, height: 14).foregroundColor(.white.opacity(0.75))
                    Rectangle().frame(width: 14, height: 1.5).foregroundColor(.white.opacity(0.75))
                    Circle().frame(width: 3, height: 3).foregroundColor(.red.opacity(0.85))
                }
                .allowsHitTesting(false)
            }

            // HUD Superior: Ronda de Zombies (estilo números romanos / tally marks) y Puntos
            VStack {
                HStack(alignment: .top) {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(points)")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 2)

                        HStack(spacing: 4) {
                            Text("RONDA")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red.opacity(0.9))
                            Text("\(roundNumber)")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(.red)
                        }
                        .shadow(color: .black, radius: 2)
                    }
                    .padding(8)
                }
                Spacer()

                // HUD Inferior: Arma M1911 Viewmodel + Munición + Indicador de Zombie objetivo
                HStack(alignment: .bottom) {
                    // Marcador de Zombie en el radar / brújula
                    if isZombieAlive {
                        let zDist = distance(fpsPosition, zombiePosition)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Circle().fill(Color.red).frame(width: 7, height: 7)
                                Text("ZOMBIE · \(Int(zDist))u")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            Text("HP: \(zombieHealth)/150")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(5)
                        .background(Color.black.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.leading, 8)
                        .padding(.bottom, 6)
                    } else {
                        Text("ZOMBIE ABATIDO (+60)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .padding(5)
                            .background(Color.black.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.leading, 8)
                            .padding(.bottom, 6)
                    }

                    Spacer()

                    // M1911 Viewmodel interactivo con animación de retroceso y fogonazo
                    ZStack(alignment: .center) {
                        if showMuzzleFlash {
                            Circle()
                                .fill(RadialGradient(colors: [.yellow, .orange, .clear], center: .center, startRadius: 2, endRadius: 35))
                                .frame(width: 65, height: 65)
                                .offset(x: -24, y: -45)
                                .allowsHitTesting(false)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("M1911")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(ammoClip)")
                                    .font(.system(size: 26, weight: .black, design: .monospaced))
                                    .foregroundColor(ammoClip > 0 ? .white : .red)
                                Text("/ \(ammoStock)")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.70))
                            }
                            if isReloading {
                                Text("RECARGANDO...")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.trailing, 10)
                        .padding(.bottom, 6)
                        .offset(y: weaponRecoil)
                    }
                    .shadow(color: .black, radius: 2)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 290)
    }

    /// Controles de movimiento táctil FPS + Botones de combate (Disparar / Recargar / Cuchillo)
    @ViewBuilder
    private var fpsControlPanel: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                // D-pad táctil direccional (WASD de movimiento en Lobby)
                HStack(spacing: 3) {
                    Button { moveFPS(forward: 0, strafe: -1, up: 0) } label: {
                        Image(systemName: "arrow.left")
                            .font(.caption2.bold())
                            .frame(width: 28, height: 26)
                    }
                    .buttonStyle(.bordered)

                    VStack(spacing: 2) {
                        Button { moveFPS(forward: 1, strafe: 0, up: 0) } label: {
                            Image(systemName: "arrow.up")
                                .font(.caption2.bold())
                                .frame(width: 28, height: 26)
                        }
                        .buttonStyle(.bordered)

                        Button { moveFPS(forward: -1, strafe: 0, up: 0) } label: {
                            Image(systemName: "arrow.down")
                                .font(.caption2.bold())
                                .frame(width: 28, height: 26)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button { moveFPS(forward: 0, strafe: 1, up: 0) } label: {
                        Image(systemName: "arrow.right")
                            .font(.caption2.bold())
                            .frame(width: 28, height: 26)
                    }
                    .buttonStyle(.bordered)
                }

                // Elevación / Noclip
                VStack(spacing: 2) {
                    Button { moveFPS(forward: 0, strafe: 0, up: 1) } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption2.bold())
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)

                    Button { moveFPS(forward: 0, strafe: 0, up: -1) } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2.bold())
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                }

                // Botón DISPARAR M1911 (Táctil grande de combate)
                Button {
                    fireWeapon()
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "scope")
                            .font(.subheadline.bold())
                        Text("DISPARAR")
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundColor(.white)
                    .frame(width: 68, height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(ammoClip > 0 ? .red : .gray)
                .disabled(ammoClip <= 0 || isReloading)

                // Botón RECARGAR
                Button {
                    reloadWeapon()
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.bold())
                        Text("RECARGAR")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 58, height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(ammoClip == 8 || ammoStock == 0 || isReloading)

                // Botón CUCHILLO
                Button {
                    meleeAttack()
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "bolt.fill")
                            .font(.caption.bold())
                        Text("CUCHILLO")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 54, height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding(.horizontal, 10)

            // Fila de utilidades: Alternador Caminar/Volar, velocidad y botón Spawn
            HStack(spacing: 8) {
                // Alternador físicas/vuelo
                Button {
                    fpsWalkMode.toggle()
                } label: {
                    Text(fpsWalkMode ? "Caminar" : "Volar")
                        .font(.caption2.bold())
                        .foregroundColor(fpsWalkMode ? .green : .yellow)
                        .frame(height: 22)
                }
                .buttonStyle(.bordered)

                // Slider velocidad
                HStack(spacing: 4) {
                    Text("Paso")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: $fpsSpeed, in: 50...600)
                    Text("\(Int(fpsSpeed))")
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                // Reset a posición inicial
                Button("Spawn") {
                    resetFPSSpawn()
                }
                .font(.caption2.bold())
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private var orbitalControlPanel: some View {
        HStack(spacing: 8) {
            Toggle("Girar", isOn: $autoRotate)
                .labelsHidden()
            Text("Girar")
                .font(.caption2)

            Text("Zoom")
                .font(.caption2)
                .foregroundColor(.secondary)
            Slider(value: $zoom, in: 0.4...4.5)

            if inspectorMode == .map {
                Button("Sala") {
                    autoRotate = false
                    pitch = 0.22
                    zoom = 2.1
                }
                .font(.caption2)
                .buttonStyle(.bordered)
                Button("General") {
                    pitch = 0.62
                    zoom = 0.90
                }
                .font(.caption2)
                .buttonStyle(.bordered)
            } else {
                Button("Centrar") {
                    yaw = 0.6
                    pitch = 0.25
                    zoom = 1.0
                    autoRotate = true
                }
                .font(.caption2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }

    // MARK: - Mecánicas de Disparo, Recarga y Detección de Impactos
    private func fireWeapon() {
        guard ammoClip > 0, !isReloading else { return }
        ammoClip -= 1

        // Retroceso visual y fogonazo del arma M1911
        weaponRecoil = 8.0
        showMuzzleFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            showMuzzleFlash = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            weaponRecoil = 0.0
        }

        // Raycasting / Detección de impacto contra el Zombie en Kino der Toten
        checkBulletHit()
    }

    private func checkBulletHit() {
        guard isZombieAlive else { return }

        // Vector director de la mirada del jugador en 3D
        let forwardVec = SIMD3<Float>(
            sin(yaw) * cos(pitch),
            cos(yaw) * cos(pitch),
            sin(pitch)
        )

        // Vector desde los ojos del jugador hacia el zombie
        let toZombie = zombiePosition + SIMD3<Float>(0, 0, 35.0) - fpsPosition
        let dist = length(toZombie)
        guard dist > 5.0 && dist < 1200.0 else { return }

        let dirToZombie = normalize(toZombie)
        let dotProduct = dot(normalize(forwardVec), dirToZombie)

        // Si el punto de mira apunta hacia el zombie (ángulo de apertura < 12 grados)
        if dotProduct > 0.978 {
            applyDamageToZombie(damage: 20, isMelee: false)
        }
    }

    private func meleeAttack() {
        guard isZombieAlive else { return }
        let toZombie = zombiePosition - fpsPosition
        let dist = length(toZombie)

        if dist < 95.0 {
            // Cuchillada a corta distancia (150 HP = abatido instantáneo en Ronda 1)
            applyDamageToZombie(damage: 150, isMelee: true)
        }
    }

    private func applyDamageToZombie(damage: Int, isMelee: Bool) {
        showHitmarker = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            showHitmarker = false
        }

        zombieHealth = max(0, zombieHealth - damage)
        if isMelee {
            points += 130 // +130 por baja con cuchillo
        } else {
            points += 10  // +10 por cada bala impactada
        }

        if zombieHealth <= 0 {
            // Zombie abatido
            isZombieAlive = false
            if !isMelee {
                points += 50 // Total +60 por baja con arma
            }

            // Reaparición del siguiente Zombie o avance de ronda tras 3 segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                spawnNextZombie()
            }
        }
    }

    private func spawnNextZombie() {
        roundNumber += 1
        zombieHealth = 150 + (roundNumber - 1) * 50
        // Aparece por las ventanas frontales del Lobby de Kino der Toten
        let spawnPoints: [SIMD3<Float>] = [
            SIMD3<Float>(350.0, -600.0, 0.0),
            SIMD3<Float>(-380.0, -650.0, 0.0),
            SIMD3<Float>(0.0, -320.0, 0.0)
        ]
        zombiePosition = spawnPoints.randomElement() ?? SIMD3<Float>(120.0, -550.0, 0.0)
        isZombieAlive = true
    }

    private func reloadWeapon() {
        guard !isReloading, ammoClip < 8, ammoStock > 0 else { return }
        isReloading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let needed = 8 - ammoClip
            let added = min(needed, ammoStock)
            ammoClip += added
            ammoStock -= added
            isReloading = false
        }
    }

    // MARK: - Game Loop (IA del Zombie, Mando de Juego y Daño)
    @State private var isGamepadConnected: Bool = false
    @State private var gamepadName: String = ""

    private func startGameLoop() {
        lastGameTick = Date()
        gameTimer?.invalidate()
        // 60 Hz / 30 Hz tick para respuesta fluida de mando y física
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            pollGamepad()
            updateGameTick()
        }
    }

    private func stopGameLoop() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    /// Sondeo y mapeo nativo de mandos de juego (PlayStation, Xbox, Switch, Backbone, etc.)
    private func pollGamepad() {
        guard let controller = GCController.current ?? GCController.controllers().first,
              let extended = controller.extendedGamepad else {
            if isGamepadConnected {
                isGamepadConnected = false
                gamepadName = ""
            }
            return
        }

        if !isGamepadConnected {
            isGamepadConnected = true
            gamepadName = controller.vendorName ?? "Mando"
        }

        guard cameraMode == .fps else { return }

        // 1. Stick Izquierdo: Movimiento de desplazamiento y avance
        let moveX = extended.leftThumbstick.xAxis.value
        let moveY = extended.leftThumbstick.yAxis.value
        let deadzone: Float = 0.12

        if abs(moveX) > deadzone || abs(moveY) > deadzone {
            let forwardAmount = moveY
            let strafeAmount = moveX
            moveFPS(forward: forwardAmount * 0.25, strafe: strafeAmount * 0.25, up: 0)
        }

        // 2. Stick Derecho: Giro de cámara (Yaw / Pitch)
        let lookX = extended.rightThumbstick.xAxis.value
        let lookY = extended.rightThumbstick.yAxis.value

        if abs(lookX) > deadzone || abs(lookY) > deadzone {
            let sensitivity: Float = 0.045
            yaw += lookX * sensitivity
            let nextPitch = pitch + lookY * sensitivity
            pitch = min(max(nextPitch, -1.35), 1.35)
        }

        // 3. Gatillo Derecho (R2 / Right Trigger): Disparar M1911
        if extended.rightTrigger.isPressed && extended.rightTrigger.value > 0.5 {
            fireWeapon()
        }

        // 4. Botón X (Xbox) / Cuadrado (PlayStation): Recargar arma
        if extended.buttonX.isPressed {
            reloadWeapon()
        }

        // 5. Botón Stick Derecho (R3) o Botón B (Círculo): Ataque con Cuchillo
        if (extended.rightThumbstickButton?.isPressed == true) || extended.buttonB.isPressed {
            meleeAttack()
        }
    }

    private func updateGameTick() {
        guard cameraMode == .fps, isZombieAlive else { return }

        // El Zombie camina lentamente hacia el jugador por el Lobby de Kino der Toten
        let delta = zombiePosition - fpsPosition
        let dist = length(delta)

        if dist > 45.0 {
            let stepSpeed: Float = 1.15
            let moveDir = normalize(fpsPosition - zombiePosition)
            zombiePosition.x += moveDir.x * stepSpeed
            zombiePosition.y += moveDir.y * stepSpeed
            // Sigue la cota del suelo de Kino
            zombiePosition.z = (zombiePosition.y > -450.0) ? 140.0 : 0.0
        } else {
            // Rango de ataque cuerpo a cuerpo del zombie contra el jugador (<45 unidades)
            playerTakeDamage(amount: 50.0)
        }
    }

    private func playerTakeDamage(amount: Float) {
        showDamageFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            showDamageFlash = false
        }

        playerHealth = max(0, playerHealth - amount)
        if playerHealth <= 0 {
            // Caída del jugador (Quick Revive / reaparición)
            playerHealth = 100.0
            resetFPSSpawn()
        }
    }

    @ViewBuilder
    private var modelListSection: some View {
        VStack(spacing: 6) {
            if !featuredInZone.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(featuredInZone) { item in
                            Button(item.name) {
                                selectModel(item)
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .tint(selectedSummary?.offset == item.offset ? .orange : .blue)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            TextField("Buscar XModel en \(entry.name)…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)

            List(filteredModels) { item in
                Button {
                    selectModel(item)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("\(item.lod0Vertices) vértices · \(item.lod0Triangles) triángulos · \(item.lod0Surfaces) sup")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedSummary?.offset == item.offset {
                            Image(systemName: "cube.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var mapSectorListSection: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Salas espaciales PVS de Kino der Toten")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("Acumular salas", isOn: $accumulateSectors)
                    .font(.caption2)
                    .fixedSize()
                    .onChange(of: accumulateSectors) { isAccum in
                        if isAccum {
                            accumulatedSectors = [selectedSectorIndex]
                        } else {
                            loadActiveMapSelection()
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)

            List(worldSectors) { sector in
                Button {
                    handleSectorTap(sector.chunkIndex)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sector.name)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("\(sector.subtitle) · \(sector.surfaceCount) sup · \(sector.triangleCount) tris")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if isSectorSelected(sector.chunkIndex) {
                            Image(systemName: accumulateSectors ? "checkmark.circle.fill" : "map.fill")
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private func isSectorSelected(_ index: Int) -> Bool {
        if accumulateSectors {
            return accumulatedSectors.contains(index)
        }
        return selectedSectorIndex == index
    }

    private func handleSectorTap(_ chunkIndex: Int) {
        selectedSectorIndex = chunkIndex
        if accumulateSectors {
            if accumulatedSectors.contains(chunkIndex) && accumulatedSectors.count > 1 {
                accumulatedSectors.remove(chunkIndex)
            } else {
                accumulatedSectors.insert(chunkIndex)
            }
        } else {
            accumulatedSectors = [chunkIndex]
        }
        loadActiveMapSelection()
    }

    private func resetFPSSpawn() {
        guard let mesh = currentMesh else { return }
        if mesh.meshId.hasPrefix("gfxworld:") {
            // Spawn oficial de Kino der Toten en el Lobby frente a Quick Revive y escaleras
            let spawnFloorZ: Float = 0.0
            fpsPosition = SIMD3<Float>(0.0, -850.0, spawnFloorZ + playerEyeHeight)
            pitch = 0.0
            yaw = 0.0
        } else {
            fpsPosition = SIMD3<Float>(mesh.center.x, mesh.center.y, mesh.mins.z + playerEyeHeight)
            pitch = 0.0
            yaw = 0.0
        }
    }

    /// Altura de ojos del jugador en unidades BO1 (~60 unidades = ~1.52m / 5 pies)
    private let playerEyeHeight: Float = 60.0
    /// Límite físico del Lobby de Kino der Toten para impedir salirse del mapa o atravesar paredes exteriores
    private let lobbyMinBounds = SIMD2<Float>(-550.0, -1480.0)
    private let lobbyMaxBounds = SIMD2<Float>(550.0, -90.0)

    private func moveFPS(forward: Float, strafe: Float, up: Float) {
        let forwardVec = SIMD3<Float>(sin(yaw), cos(yaw), 0)
        let rightVec = SIMD3<Float>(cos(yaw), -sin(yaw), 0)
        let step = fpsSpeed * 0.20

        var nextPos = fpsPosition + forwardVec * (forward * step) + rightVec * (strafe * step)

        if fpsWalkMode && currentMesh?.meshId.hasPrefix("gfxworld:") == true {
            // 1. Colisión contra paredes del Lobby (eje X e Y)
            nextPos.x = min(max(nextPos.x, lobbyMinBounds.x), lobbyMaxBounds.x)
            nextPos.y = min(max(nextPos.y, lobbyMinBounds.y), lobbyMaxBounds.y)

            // 2. Piso firme y gravedad auténtica:
            // En el Lobby de Kino der Toten, el suelo plano está en Z ≈ 0.0 y la zona de escaleras/balcón sube hasta Z ≈ 140.0.
            // Si el jugador intenta elevarse manualmente o caer, la gravedad lo sostiene a altura de ojos sobre el piso.
            let floorZ: Float = (nextPos.y > -450.0) ? 140.0 : 0.0
            nextPos.z = floorZ + playerEyeHeight
        } else {
            // Noclip libre (modo visor clásico)
            nextPos.z += up * step
        }

        fpsPosition = nextPos
    }

    private func selectModel(_ summary: XModelSummary) {
        selectedSummary = summary
        guard let stream = decompressedStream else { return }
        if let mesh = try? XModelReader.extractMesh(from: stream, at: summary.offset) {
            currentMesh = mesh
            zoom = 1.0
            if cameraMode == .fps {
                resetFPSSpawn()
            }
        }
    }

    private func loadActiveMapSelection() {
        guard let stream = decompressedStream else { return }
        let indicesToLoad = accumulateSectors ? Array(accumulatedSectors).sorted() : [selectedSectorIndex]
        isExtractingSector = true

        Task.detached(priority: .userInitiated) {
            let extracted = try? XModelReader.extractWorldSectors(from: stream, sectorIndices: indicesToLoad)
            await MainActor.run {
                if let mesh = extracted {
                    currentMesh = mesh
                    if cameraMode == .fps {
                        resetFPSSpawn()
                    }
                }
                isExtractingSector = false
            }
        }
    }

    private func loadZoneModels() async {
        isLoading = true
        errorMessage = nil

        let folderURL = gameFolder
        let relPath = entry.relativePath

        let result: Result<(Data, [XModelSummary], [XModelReader.GfxWorldSectorInfo], XModelMesh?), Error> = await Task.detached(priority: .userInitiated) {
            let accessed = folderURL.startAccessingSecurityScopedResource()
            defer {
                if accessed { folderURL.stopAccessingSecurityScopedResource() }
            }

            var zoneURL = folderURL.appendingPathComponent(GameFolderValidator.zoneFolderName, isDirectory: true)
            for part in relPath.split(separator: "/") {
                zoneURL.appendPathComponent(String(part))
            }

            do {
                let stream = try XModelReader.decompressZone(at: zoneURL)
                let scanned = XModelReader.scanModels(in: stream)
                let sectors = XModelReader.scanWorldSectors(in: stream)
                let map = Dictionary(uniqueKeysWithValues: scanned.map { ($0.name, $0) })
                let initial = XModelReader.featuredModels.compactMap { map[$0] }.first ?? scanned.first
                let initialMesh = try initial.map { try XModelReader.extractMesh(from: stream, at: $0.offset) }
                return .success((stream, scanned, sectors, initialMesh))
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let (stream, scanned, sectors, initialMesh)):
            decompressedStream = stream
            models = scanned
            worldSectors = sectors
            if let initialMesh {
                currentMesh = initialMesh
                selectedSummary = scanned.first { $0.offset == initialMesh.offset }
                if cameraMode == .fps {
                    resetFPSSpawn()
                }
            } else if !sectors.isEmpty {
                inspectorMode = .map
                loadActiveMapSelection()
            }
            isLoading = false
        case .failure(let error):
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
