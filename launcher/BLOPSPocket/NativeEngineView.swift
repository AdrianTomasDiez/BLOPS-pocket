import SwiftUI
import UIKit
import MetalKit

/// Puente C extern para ciclo de vida del motor C++ de Treyarch
@_silgen_name("bo1_ios_init")
func bo1_ios_init(_ gameDirectory: UnsafePointer<CChar>)

@_silgen_name("bo1_ios_frame")
func bo1_ios_frame()

@_silgen_name("bo1_ios_execute_command")
func bo1_ios_execute_command(_ cmd: UnsafePointer<CChar>)

@_silgen_name("bo1_ios_set_present_callback")
func bo1_ios_set_present_callback(_ cb: (@convention(c) () -> Void)?)

@_silgen_name("bo1_ios_get_progress_info")
func bo1_ios_get_progress_info(
    _ outZone: UnsafeMutablePointer<CChar>?, _ maxZoneLen: Int32,
    _ outAsset: UnsafeMutablePointer<CChar>?, _ maxAssetLen: Int32,
    _ outCurrent: UnsafeMutablePointer<Int32>?, _ outTotal: UnsafeMutablePointer<Int32>?,
    _ outPercent: UnsafeMutablePointer<Int32>?,
    _ outStage: UnsafeMutablePointer<CChar>?, _ maxStageLen: Int32,
    _ outError: UnsafeMutablePointer<CChar>?, _ maxErrorLen: Int32,
    _ outHasError: UnsafeMutablePointer<Int32>?,
    _ outIsComplete: UnsafeMutablePointer<Int32>?
)

/// Vista que alberga la ejecución del motor nativo C++ de Call of Duty: Black Ops 1 Zombies.
struct NativeEngineView: View {
    let gameFolder: URL
    @Environment(\.dismiss) private var dismiss
    @State private var isEngineReady: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EngineViewControllerRepresentable(gameFolder: gameFolder, onEngineReady: {
                withAnimation(.easeInOut(duration: 0.7)) {
                    isEngineReady = true
                }
            })
            .ignoresSafeArea()

            // Pantalla de carga cinematográfica para Kino der Toten con telemetría C++ en tiempo real
            if !isEngineReady {
                KinoLoadingScreenView(gameFolder: gameFolder, onComplete: {
                    withAnimation(.easeInOut(duration: 0.7)) {
                        isEngineReady = true
                    }
                })
                .transition(.opacity)
                .zIndex(2)
            }

            // Controles táctiles virtuales en pantalla (se muestran al terminar la carga)
            VirtualGameControls()
                .ignoresSafeArea()
                .opacity(isEngineReady ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5), value: isEngineReady)
                .zIndex(1)

            // Botón sutil de salida / pausa en la esquina superior izquierda
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(16)
                    }
                    Spacer()
                }
                Spacer()
            }
            .zIndex(3)
        }
        .statusBar(hidden: true)
    }
}

/// Pantalla de carga temática de Kino der Toten conectada 1:1 a la base de datos C++ de Treyarch
struct KinoLoadingScreenView: View {
    let gameFolder: URL
    var onComplete: (() -> Void)? = nil

    @State private var elapsedTime: Double = 0.0
    @State private var zoneName: String = "Iniciando..."
    @State private var assetName: String = "Arrancando motor Treyarch"
    @State private var stageText: String = "Iniciando subsistemas"
    @State private var currentAssetCount: Int = 0
    @State private var totalAssetCount: Int = 0
    @State private var progressPercent: Double = 0.02
    @State private var errorMessage: String = ""
    @State private var hasError: Bool = false
    @State private var isComplete: Bool = false

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Imagen artística de fondo de Kino der Toten
            Image("kino_load")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            // Viñeteado y degradado oscuro para contraste de la interfaz
            LinearGradient(
                colors: [Color.black.opacity(0.2), Color.black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.55)]),
                center: .center,
                startRadius: 250,
                endRadius: 800
            )
            .ignoresSafeArea()

            // Contenido en capas: título del mapa a la izquierda, telemetría a la derecha
            VStack {
                // Banner de error destacado si el motor detecta un fallo nativo
                if hasError {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.red)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("ERROR DEL MOTOR NATIVO (TREYARCH)")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(.red)

                            Text(errorMessage)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(3)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.black.opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 2)
                    )
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 20) {
                    // Título inferior izquierdo con estética Call of Duty Black Ops
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 0) {
                            Text("bo1:")
                                .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.0))
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                            Text("zombie_theater")
                                .foregroundColor(.white)
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                        }

                        Text("KINO DER TOTEN - SURVIVAL")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.8))
                            .tracking(2)
                    }

                    Spacer()

                    // Panel lateral derecho: métricas de carga REALES leídas de Treyarch FastFiles
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 10) {
                            Text(hasError ? "Detenido por error" : "Cargando")
                                .foregroundColor(hasError ? .red : .white)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            Text(String(format: "%.1f s", elapsedTime))
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }
                        .padding(.bottom, 4)

                        StatRow(label: "Estado", value: stageText, color: hasError ? .red : Color(red: 1.0, green: 0.78, blue: 0.25))
                        StatRow(label: "Zona (FF)", value: zoneName, color: Color(red: 1.0, green: 0.55, blue: 0.15))
                        StatRow(label: "Asset actual", value: truncateAsset(assetName), color: Color(red: 0.42, green: 0.92, blue: 0.55))
                        StatRow(label: "Archivos", value: "\(currentAssetCount) / \(totalAssetCount)", color: Color(red: 1.0, green: 0.7, blue: 0.25))
                        StatRow(label: "Porcentaje", value: "\(Int(progressPercent * 100))%", color: Color(red: 0.42, green: 0.92, blue: 0.55))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 12)

                // Subtexto con nombre de asset y contador X/Y
                HStack {
                    Text(assetName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.75))
                        .lineLimit(1)

                    Spacer()

                    Text("\(currentAssetCount) / \(totalAssetCount) assets (\(Int(progressPercent * 100))%)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(hasError ? .red : Color(red: 1.0, green: 0.72, blue: 0.25))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 4)

                // Barra de progreso inferior brillante que refleja el conteo real
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: hasError ? [Color.red, Color.orange] : [Color(red: 1.0, green: 0.38, blue: 0.0), Color(red: 1.0, green: 0.72, blue: 0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * CGFloat(progressPercent)), height: 6)
                            .shadow(color: (hasError ? Color.red : Color(red: 1.0, green: 0.45, blue: 0.0)).opacity(0.85), radius: 5)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 40)
                .padding(.bottom, 18)
            }
        }
        .onReceive(timer) { _ in
            elapsedTime += 0.1
            pollProgress()
        }
    }

    private func truncateAsset(_ name: String) -> String {
        if name.count > 28 {
            return "..." + String(name.suffix(25))
        }
        return name
    }

    private func pollProgress() {
        var zoneBuf = [CChar](repeating: 0, count: 256)
        var assetBuf = [CChar](repeating: 0, count: 256)
        var stageBuf = [CChar](repeating: 0, count: 128)
        var errBuf = [CChar](repeating: 0, count: 512)
        var current: Int32 = 0
        var total: Int32 = 0
        var pct: Int32 = 0
        var errFlag: Int32 = 0
        var compFlag: Int32 = 0

        bo1_ios_get_progress_info(
            &zoneBuf, 256,
            &assetBuf, 256,
            &current, &total,
            &pct,
            &stageBuf, 128,
            &errBuf, 512,
            &errFlag,
            &compFlag
        )

        let zStr = String(cString: zoneBuf).trimmingCharacters(in: .whitespacesAndNewlines)
        let aStr = String(cString: assetBuf).trimmingCharacters(in: .whitespacesAndNewlines)
        let sStr = String(cString: stageBuf).trimmingCharacters(in: .whitespacesAndNewlines)
        let eStr = String(cString: errBuf).trimmingCharacters(in: .whitespacesAndNewlines)

        if !zStr.isEmpty { zoneName = zStr }
        if !aStr.isEmpty { assetName = aStr }
        if !sStr.isEmpty { stageText = sStr }

        if errFlag != 0 {
            hasError = true
            errorMessage = eStr.isEmpty ? "Error nativo en motor Treyarch" : eStr
        }

        currentAssetCount = Int(current)
        totalAssetCount = Int(total)

        if total > 0 {
            let frac = Double(current) / Double(total)
            progressPercent = max(0.02, min(1.0, frac))
        } else if pct > 0 {
            progressPercent = max(0.02, min(1.0, Double(pct) / 100.0))
        }

        if compFlag != 0 && !isComplete {
            isComplete = true
            progressPercent = 1.0
            onComplete?()
        }
    }
}

/// Fila individual de telemetría de carga
struct StatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

/// Puente UIViewControllerRepresentable para el controlador nativo del motor
struct EngineViewControllerRepresentable: UIViewControllerRepresentable {
    let gameFolder: URL
    let onEngineReady: () -> Void

    func makeUIViewController(context: Context) -> EngineViewController {
        let vc = EngineViewController()
        vc.gameFolderURL = gameFolder
        vc.onEngineReady = onEngineReady
        return vc
    }

    func updateUIViewController(_ uiViewController: EngineViewController, context: Context) {}
}

/// Controlador de vista principal que hospeda el MTKView y el ciclo de vida del motor C++
class EngineViewController: UIViewController {
    var gameFolderURL: URL?
    var onEngineReady: (() -> Void)?

    private var metalView: MTKView?
    private var displayLink: CADisplayLink?
    private var securityAccessActive = false

    private var commandQueue: MTLCommandQueue?
    private static weak var sharedMetalView: MTKView?
    private static var sharedCommandQueue: MTLCommandQueue?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[Engine] Metal no está soportado en este dispositivo.")
            return
        }

        let mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mtkView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat = .depth32Float
        view.addSubview(mtkView)
        self.metalView = mtkView
        self.commandQueue = device.makeCommandQueue()
        EngineViewController.sharedMetalView = mtkView
        EngineViewController.sharedCommandQueue = self.commandQueue

        // Configurar callback de presentación de Treyarch -> Metal
        bo1_ios_set_present_callback {
            guard let view = EngineViewController.sharedMetalView,
                  let drawable = view.currentDrawable,
                  let queue = EngineViewController.sharedCommandQueue,
                  let commandBuffer = queue.makeCommandBuffer() else {
                return
            }
            if let renderPassDesc = view.currentRenderPassDescriptor,
               let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) {
                encoder.endEncoding()
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        setupEngine()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    private var engineReady = false

    /// Añade una línea a bo1_console.log (Documents/ y Documents/BLOPS/), igual que el motor.
    private func appendLauncherLog(_ message: String) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = (message + "\n").data(using: .utf8) else { return }
        let blopsDir = docs.appendingPathComponent("BLOPS")
        for targetURL in [docs.appendingPathComponent("bo1_console.log"), blopsDir.appendingPathComponent("bo1_console.log")] {
            if FileManager.default.fileExists(atPath: targetURL.path), let handle = try? FileHandle(forWritingTo: targetURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: targetURL)
            }
        }
    }

    private func setupEngine() {
        guard let folder = gameFolderURL else { return }
        print("[Engine] Inicializando motor nativo BO1 Zombies con carpeta: \(folder.path)")

        // Escribir traza de inicio desde Swift tanto a Documents/ como a Documents/BLOPS/
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logURL = docs.appendingPathComponent("bo1_console.log")
            let blopsDir = docs.appendingPathComponent("BLOPS")
            try? FileManager.default.createDirectory(at: blopsDir, withIntermediateDirectories: true)
            let blopsLogURL = blopsDir.appendingPathComponent("bo1_console.log")

            let startupMsg = "\n=== [BLOPS Launcher] Pulsado INICIAR PARTIDA - Carpeta: \(folder.path) ===\n"
            if let data = startupMsg.data(using: .utf8) {
                for targetURL in [logURL, blopsLogURL] {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        if let handle = try? FileHandle(forWritingTo: targetURL) {
                            handle.seekToEndOfFile()
                            handle.write(data)
                            try? handle.close()
                        }
                    } else {
                        try? data.write(to: targetURL)
                    }
                }
            }
        }

        // Configurar CADisplayLink para el refresco por frame a 60/120 Hz
        displayLink = CADisplayLink(target: self, selector: #selector(engineTick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)

        // Inicializar motor Treyarch en hilo secundario para mantener el loading screen fluido
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.securityAccessActive = folder.startAccessingSecurityScopedResource()

            // El motor exige main/fileSysCheck.cfg y main/playlists_sp.info en la carpeta del juego; la copia
            // de PC los trae y la de iOS no. Se crean solo si faltan.
            do {
                let created = try BaseGameData.ensureInstalled(in: folder)
                let check = folder.appendingPathComponent("main/fileSysCheck.cfg").path
                self.appendLauncherLog("[BLOPS Launcher] Archivos base creados: \(created) | fileSysCheck.cfg existe: \(FileManager.default.fileExists(atPath: check))")
            } catch {
                self.appendLauncherLog("[BLOPS Launcher] ERROR creando archivos base en main/: \(error)")
            }

            folder.path.withCString { cPath in
                bo1_ios_init(cPath)
            }

            DispatchQueue.main.async {
                self.engineReady = true
                print("[Engine] Motor de Treyarch iniciado. Ejecutando frames de Com_Frame para Kino der Toten.")
            }
        }
    }

    @objc private func engineTick() {
        // En cada tick de refresco de pantalla se llama al Com_Frame() del motor C++ una vez inicializado
        if engineReady {
            bo1_ios_frame()
        }
    }

    deinit {
        bo1_ios_set_present_callback(nil)
        displayLink?.invalidate()
        if securityAccessActive, let folder = gameFolderURL {
            folder.stopAccessingSecurityScopedResource()
        }
    }
}
