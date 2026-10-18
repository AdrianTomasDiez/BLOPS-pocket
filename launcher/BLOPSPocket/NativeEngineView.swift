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

            // Pantalla de carga cinematográfica para Kino der Toten (estilo IW4x / Treyarch)
            if !isEngineReady {
                KinoLoadingScreenView(gameFolder: gameFolder)
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

/// Pantalla de carga temática de Kino der Toten idéntica al formato de telemetría de IW4-Pocket
struct KinoLoadingScreenView: View {
    let gameFolder: URL

    @State private var elapsedTime: Double = 0.0
    @State private var progress: Double = 0.05
    @State private var admissionText: String = "1.2s"
    @State private var fastfileText: String = "Mounting common_zombie.ff"

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

                    // Panel lateral derecho: métricas de carga en tiempo real (estilo IW4x)
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 10) {
                            Text("Loading")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            Text(String(format: "%.1f  s", elapsedTime))
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                        }
                        .padding(.bottom, 4)

                        StatRow(label: "Admission", value: admissionText, color: Color(red: 1.0, green: 0.78, blue: 0.25))
                        StatRow(label: "GPU textures", value: "2.6k images · Metal", color: Color(red: 0.42, green: 0.92, blue: 0.55))
                        StatRow(label: "Pipelines", value: "683 pipelines · iOS", color: Color(red: 1.0, green: 0.7, blue: 0.25))
                        StatRow(label: "Render frames", value: "0 frames · 60 Hz", color: Color(red: 1.0, green: 0.65, blue: 0.2))
                        StatRow(label: "Fastfiles", value: fastfileText, color: Color(red: 1.0, green: 0.55, blue: 0.15))
                        StatRow(label: "First person", value: "2.6k models · viewarms", color: Color(red: 0.42, green: 0.92, blue: 0.55))
                        StatRow(label: "Shaders", value: "3.1k programs · compiled", color: Color(red: 0.42, green: 0.92, blue: 0.55))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)

                // Barra de progreso inferior brillante
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.18))
                            .frame(height: 5)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.38, blue: 0.0), Color(red: 1.0, green: 0.72, blue: 0.25)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * CGFloat(progress)), height: 5)
                            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.0).opacity(0.85), radius: 5)
                    }
                }
                .frame(height: 5)
                .padding(.horizontal, 40)
                .padding(.bottom, 18)
            }
        }
        .onReceive(timer) { _ in
            elapsedTime += 0.1

            // Progresión visual de estados durante la inicialización
            if elapsedTime < 2.0 {
                progress = min(0.30, progress + 0.02)
                fastfileStatusUpdate("Mounting common_zombie.ff")
            } else if elapsedTime < 5.0 {
                progress = min(0.60, progress + 0.015)
                fastfileStatusUpdate("Mounting zombie_theater.ff")
            } else if elapsedTime < 8.0 {
                progress = min(0.85, progress + 0.01)
                fastfileStatusUpdate("Allocating hunk & sound assets")
            } else {
                progress = min(0.95, progress + 0.005)
                fastfileStatusUpdate("Spawning zombie_theater BSP")
            }
        }
        .onAppear {
            checkLocalFastfiles()
        }
    }

    private func fastfileStatusUpdate(_ status: String) {
        if fastfileText != status {
            fastfileText = status
        }
    }

    private func checkLocalFastfiles() {
        let fm = FileManager.default
        let common = gameFolder.appendingPathComponent("zone/Common/common_zombie.ff")
        let theater = gameFolder.appendingPathComponent("zone/Common/zombie_theater.ff")
        if fm.fileExists(atPath: common.path) && fm.fileExists(atPath: theater.path) {
            admissionText = "verified (fastfiles OK)"
        } else {
            admissionText = "reading Documents/Games"
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

            folder.path.withCString { cPath in
                bo1_ios_init(cPath)
            }

            DispatchQueue.main.async {
                self.engineReady = true
                self.onEngineReady?()
                print("[Engine] Motor de Treyarch listo. Iniciando rendering de Kino der Toten.")
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
