import SwiftUI

/// Pantalla completa auténtica de Call of Duty: Black Ops Zombies en Kino der Toten.
/// Sin listas de archivos, sin botones de depurador, a pantalla completa horizontal.
struct KinoGameView: View {
    let gameFolder: URL
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var loadingStage = "Iniciando Kino der Toten…"
    @State private var errorMessage: String?
    @State private var currentMesh: XModelMesh?

    // Parámetros de Cámara y FPS
    @State private var yaw: Float = 0.0
    @State private var pitch: Float = 0.0
    @State private var fpsPosition = SIMD3<Float>(0.0, -850.0, 60.0)
    @State private var fpsSpeed: Float = 250.0

    // Estado del Juego
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

    // Zombi y Entidades
    @State private var zombiePosition = SIMD3<Float>(120.0, -550.0, 0.0)
    @State private var zombieHealth: Int = 150
    @State private var isZombieAlive: Bool = true
    @State private var gameTimer: Timer? = nil

    // Mando de juego
    @State private var isGamepadConnected: Bool = false
    @State private var gamepadName: String = ""

    private let playerEyeHeight: Float = 60.0
    private let lobbyMinBounds = SIMD2<Float>(-550.0, -1480.0)
    private let lobbyMaxBounds = SIMD2<Float>(550.0, -90.0)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                loadingScreen
            } else if let errorMessage {
                errorScreen(errorMessage)
            } else if let mesh = currentMesh {
                // Viewport 3D Metal a pantalla completa
                XModelMetalSurfaceView(
                    mesh: mesh,
                    yaw: $yaw,
                    pitch: $pitch,
                    zoom: .constant(1.0),
                    autoRotate: .constant(false),
                    wireframe: .constant(false),
                    shadingMode: .constant(.directional),
                    cameraMode: .constant(.fps),
                    fpsPosition: $fpsPosition
                )
                .ignoresSafeArea()
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            yaw += Float(value.translation.width) * 0.005
                            let nextPitch = pitch + Float(value.translation.height) * 0.005
                            pitch = min(max(nextPitch, -1.35), 1.35)
                        }
                )

                // HUD Auténtico de Zombies
                gameplayHUD
            }
        }
        .statusBar(hidden: true)
        .task {
            await loadKinoMap()
            startGameLoop()
        }
        .onDisappear {
            stopGameLoop()
        }
    }

    // MARK: - Pantalla de Carga Oficial
    private var loadingScreen: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("KINO DER TOTEN")
                .font(.system(size: 38, weight: .black, design: .serif))
                .foregroundColor(.red)
                .tracking(4)
                .shadow(color: .red.opacity(0.6), radius: 10)

            Text("BERLÍN, 1963")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .tracking(2)

            Spacer()

            VStack(spacing: 8) {
                ProgressView()
                    .tint(.red)
                    .scaleEffect(1.2)
                Text(loadingStage)
                    .font(.caption.monospaced())
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 30)
        }
    }

    private func errorScreen(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text("Error al cargar Kino der Toten")
                .font(.headline)
                .foregroundColor(.white)
            Text(msg)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Volver al Menú") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    // MARK: - HUD Auténtico de Call of Duty
    private var gameplayHUD: some View {
        ZStack {
            // Flash rojo al ser herido
            if showDamageFlash {
                Color.red.opacity(0.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Crosshair o Hitmarker
            if showHitmarker {
                Image(systemName: "xmark")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.red)
                    .shadow(color: .black, radius: 3)
                    .allowsHitTesting(false)
            } else {
                ZStack {
                    Rectangle().frame(width: 1.5, height: 16).foregroundColor(.white.opacity(0.75))
                    Rectangle().frame(width: 16, height: 1.5).foregroundColor(.white.opacity(0.75))
                    Circle().frame(width: 3, height: 3).foregroundColor(.red.opacity(0.85))
                }
                .allowsHitTesting(false)
            }

            // HUD Superior Izquierdo: Menú de Pausa / Salir
            VStack {
                HStack {
                    Button {
                        stopGameLoop()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("MENÚ")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)

                    if isGamepadConnected {
                        HStack(spacing: 4) {
                            Image(systemName: "gamecontroller.fill")
                            Text(gamepadName)
                        }
                        .font(.caption.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.top, 10)
                    }

                    Spacer()

                    // Puntos (estilo Call of Duty en amarillo)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(points)")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 3)
                    }
                    .padding(.trailing, 25)
                    .padding(.top, 10)
                }
                Spacer()

                // HUD Inferior: Ronda a la izquierda, Arma y Munición a la derecha
                HStack(alignment: .bottom) {
                    // Ronda estilo números romanos en rojo
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text("RONDA")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red.opacity(0.9))
                            Text("\(roundNumber)")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.red)
                        }
                        .shadow(color: .black, radius: 3)

                        if isZombieAlive {
                            let zDist = distance(fpsPosition, zombiePosition)
                            Text("ZOMBI: \(Int(zDist))u · HP: \(zombieHealth)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.leading, 25)
                    .padding(.bottom, 20)

                    Spacer()

                    // Controles táctiles transparentes si no hay mando
                    if !isGamepadConnected {
                        touchControlsOverlay
                    }

                    Spacer()

                    // Viewmodel de M1911 y Munición
                    ZStack(alignment: .bottomTrailing) {
                        if showMuzzleFlash {
                            Circle()
                                .fill(RadialGradient(colors: [.yellow, .orange, .clear], center: .center, startRadius: 2, endRadius: 50))
                                .frame(width: 90, height: 90)
                                .offset(x: -30, y: -60)
                                .allowsHitTesting(false)
                        }

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("COLT M1911")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.white.opacity(0.9))

                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text("\(ammoClip)")
                                    .font(.system(size: 34, weight: .black, design: .monospaced))
                                    .foregroundColor(ammoClip > 0 ? .white : .red)
                                Text("/ \(ammoStock)")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.70))
                            }

                            if isReloading {
                                Text("RECARGANDO...")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        .offset(y: weaponRecoil)
                        .shadow(color: .black, radius: 4)
                    }
                    .padding(.trailing, 25)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // Controles táctiles transparentes y minimalistas para no ensuciar la pantalla
    private var touchControlsOverlay: some View {
        HStack(spacing: 16) {
            // D-Pad movimiento
            HStack(spacing: 4) {
                Button { moveFPS(forward: 0, strafe: -1) } label: {
                    Image(systemName: "arrow.left")
                        .font(.body.bold())
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                VStack(spacing: 4) {
                    Button { moveFPS(forward: 1, strafe: 0) } label: {
                        Image(systemName: "arrow.up")
                            .font(.body.bold())
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    Button { moveFPS(forward: -1, strafe: 0) } label: {
                        Image(systemName: "arrow.down")
                            .font(.body.bold())
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                Button { moveFPS(forward: 0, strafe: 1) } label: {
                    Image(systemName: "arrow.right")
                        .font(.body.bold())
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .foregroundColor(.white)

            // Botones de acción táctiles
            HStack(spacing: 10) {
                Button {
                    fireWeapon()
                } label: {
                    Text("DISPARAR")
                        .font(.system(size: 11, weight: .black))
                        .frame(width: 75, height: 46)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(ammoClip <= 0 || isReloading)

                Button {
                    reloadWeapon()
                } label: {
                    Text("RECARGAR")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 65, height: 46)
                        .background(Color.blue.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(ammoClip == 8 || ammoStock == 0 || isReloading)

                Button {
                    meleeAttack()
                } label: {
                    Text("CUCHILLO")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 65, height: 46)
                        .background(Color.purple.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.bottom, 15)
    }

    // MARK: - Carga de Kino der Toten
    private func loadKinoMap() async {
        isLoading = true
        loadingStage = "Abriendo zombie_theater.ff…"

        let folder = gameFolder
        let res: Result<XModelMesh, Error> = await Task.detached(priority: .userInitiated) {
            let accessed = folder.startAccessingSecurityScopedResource()
            defer { if accessed { folder.stopAccessingSecurityScopedResource() } }

            let zoneFolder = folder.appendingPathComponent(GameFolderValidator.zoneFolderName, isDirectory: true)
            // Buscar zombie_theater.ff en subcarpetas de idiomas (Common, english, etc.)
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(at: zoneFolder, includingPropertiesForKeys: nil) else {
                return .failure(NSError(domain: "BLOPS", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo leer la carpeta zone"]))
            }

            var theaterURL: URL?
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.lowercased() == "zombie_theater.ff" {
                    theaterURL = fileURL
                    break
                }
            }

            guard let finalURL = theaterURL else {
                return .failure(NSError(domain: "BLOPS", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se encontró zombie_theater.ff en la carpeta zone"]))
            }

            do {
                let stream = try XModelReader.decompressZone(at: finalURL)
                // Cargar todas las salas del mapa (Lobby, Foyer, Auditorio...)
                let sectors = XModelReader.scanWorldSectors(in: stream)
                let indices = sectors.map { $0.chunkIndex }
                guard let mesh = try XModelReader.extractWorldSectors(from: stream, sectorIndices: indices.isEmpty ? [0] : indices) else {
                    return .failure(NSError(domain: "BLOPS", code: 3, userInfo: [NSLocalizedDescriptionKey: "No se pudo extraer la geometría de Kino"]))
                }
                return .success(mesh)
            } catch {
                return .failure(error)
            }
        }.value

        switch res {
        case .success(let mesh):
            currentMesh = mesh
            fpsPosition = SIMD3<Float>(0.0, -850.0, playerEyeHeight)
            pitch = 0.0
            yaw = 0.0
            isLoading = false
        case .failure(let err):
            errorMessage = err.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Lógica de Juego y Mando
    private func fireWeapon() {
        guard ammoClip > 0, !isReloading else { return }
        ammoClip -= 1
        weaponRecoil = 9.0
        showMuzzleFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { showMuzzleFlash = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { weaponRecoil = 0.0 }
        checkBulletHit()
    }

    private func checkBulletHit() {
        guard isZombieAlive else { return }
        let forwardVec = SIMD3<Float>(sin(yaw) * cos(pitch), cos(yaw) * cos(pitch), sin(pitch))
        let toZombie = zombiePosition + SIMD3<Float>(0, 0, 35.0) - fpsPosition
        let dist = length(toZombie)
        guard dist > 5.0 && dist < 1200.0 else { return }

        let dotProduct = dot(normalize(forwardVec), normalize(toZombie))
        if dotProduct > 0.978 {
            applyDamage(damage: 20, isMelee: false)
        }
    }

    private func meleeAttack() {
        guard isZombieAlive else { return }
        let dist = length(zombiePosition - fpsPosition)
        if dist < 95.0 {
            applyDamage(damage: 150, isMelee: true)
        }
    }

    private func applyDamage(damage: Int, isMelee: Bool) {
        showHitmarker = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { showHitmarker = false }

        zombieHealth = max(0, zombieHealth - damage)
        points += isMelee ? 130 : 10

        if zombieHealth <= 0 {
            isZombieAlive = false
            if !isMelee { points += 50 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                roundNumber += 1
                zombieHealth = 150 + (roundNumber - 1) * 50
                zombiePosition = SIMD3<Float>(Float.random(in: -300...300), -550.0, 0.0)
                isZombieAlive = true
            }
        }
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

    private func moveFPS(forward: Float, strafe: Float) {
        let forwardVec = SIMD3<Float>(sin(yaw), cos(yaw), 0)
        let rightVec = SIMD3<Float>(cos(yaw), -sin(yaw), 0)
        let step = fpsSpeed * 0.20

        var nextPos = fpsPosition + forwardVec * (forward * step) + rightVec * (strafe * step)
        nextPos.x = min(max(nextPos.x, lobbyMinBounds.x), lobbyMaxBounds.x)
        nextPos.y = min(max(nextPos.y, lobbyMinBounds.y), lobbyMaxBounds.y)
        let floorZ: Float = (nextPos.y > -450.0) ? 140.0 : 0.0
        nextPos.z = floorZ + playerEyeHeight
        fpsPosition = nextPos
    }

    private func startGameLoop() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            pollGamepad()
            updateZombieAI()
        }
    }

    private func stopGameLoop() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    private func pollGamepad() {
        guard let controller = GCController.current ?? GCController.controllers().first,
              let ext = controller.extendedGamepad else {
            if isGamepadConnected { isGamepadConnected = false; gamepadName = "" }
            return
        }

        if !isGamepadConnected {
            isGamepadConnected = true
            gamepadName = controller.vendorName ?? "Mando Conectado"
        }

        let mx = ext.leftThumbstick.xAxis.value
        let my = ext.leftThumbstick.yAxis.value
        if abs(mx) > 0.12 || abs(my) > 0.12 {
            moveFPS(forward: my * 0.25, strafe: mx * 0.25)
        }

        let lx = ext.rightThumbstick.xAxis.value
        let ly = ext.rightThumbstick.yAxis.value
        if abs(lx) > 0.12 || abs(ly) > 0.12 {
            yaw += lx * 0.045
            let np = pitch + ly * 0.045
            pitch = min(max(np, -1.35), 1.35)
        }

        if ext.rightTrigger.isPressed && ext.rightTrigger.value > 0.5 {
            fireWeapon()
        }
        if ext.buttonX.isPressed {
            reloadWeapon()
        }
        if (ext.rightThumbstickButton?.isPressed == true) || ext.buttonB.isPressed {
            meleeAttack()
        }
    }

    private func updateZombieAI() {
        guard isZombieAlive else { return }
        let delta = zombiePosition - fpsPosition
        let dist = length(delta)

        if dist > 45.0 {
            let moveDir = normalize(fpsPosition - zombiePosition)
            zombiePosition.x += moveDir.x * 1.15
            zombiePosition.y += moveDir.y * 1.15
            zombiePosition.z = (zombiePosition.y > -450.0) ? 140.0 : 0.0
        } else {
            // Golpe al jugador
            showDamageFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { showDamageFlash = false }
            playerHealth = max(0, playerHealth - 50.0)
            if playerHealth <= 0 {
                playerHealth = 100.0
                fpsPosition = SIMD3<Float>(0.0, -850.0, playerEyeHeight)
            }
        }
    }
}
