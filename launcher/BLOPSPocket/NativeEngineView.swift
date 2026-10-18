import SwiftUI
import UIKit
import MetalKit

/// Puente C extern para ciclo de vida del motor C++ de Treyarch
@_silgen_name("bo1_ios_init")
func bo1_ios_init(_ gameDirectory: UnsafePointer<CChar>)

@_silgen_name("bo1_ios_frame")
func bo1_ios_frame()

/// Vista que alberga la ejecución del motor nativo C++ de Call of Duty: Black Ops 1 Zombies.
struct NativeEngineView: View {
    let gameFolder: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EngineViewControllerRepresentable(gameFolder: gameFolder)
                .ignoresSafeArea()

            // Controles táctiles virtuales en pantalla
            VirtualGameControls()
                .ignoresSafeArea()

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
        }
        .statusBar(hidden: true)
    }
}

/// Puente UIViewControllerRepresentable para el controlador nativo del motor
struct EngineViewControllerRepresentable: UIViewControllerRepresentable {
    let gameFolder: URL

    func makeUIViewController(context: Context) -> EngineViewController {
        let vc = EngineViewController()
        vc.gameFolderURL = gameFolder
        return vc
    }

    func updateUIViewController(_ uiViewController: EngineViewController, context: Context) {}
}

/// Controlador de vista principal que hospeda el MTKView y el ciclo de vida del motor C++
class EngineViewController: UIViewController {
    var gameFolderURL: URL?
    private var metalView: MTKView?
    private var displayLink: CADisplayLink?

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

        setupEngine()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    private func setupEngine() {
        guard let folder = gameFolderURL else { return }
        print("[Engine] Inicializando motor nativo BO1 Zombies con carpeta: \(folder.path)")

        folder.path.withCString { cPath in
            bo1_ios_init(cPath)
        }

        // Configurar CADisplayLink para el refresco por frame a 60/120 Hz
        displayLink = CADisplayLink(target: self, selector: #selector(engineTick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func engineTick() {
        // En cada tick de refresco de pantalla se llama al Com_Frame() del motor C++
        bo1_ios_frame()
    }

    deinit {
        displayLink?.invalidate()
    }
}
