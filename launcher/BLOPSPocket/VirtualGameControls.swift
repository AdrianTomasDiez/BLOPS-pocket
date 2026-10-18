import SwiftUI
import GameController

/// Códigos de teclas de CoD / Quake engine para la entrada táctil
enum NativeEngineKey: Int32 {
    case moveForward = 0x77  // 'w'
    case moveBack    = 0x73  // 's'
    case moveLeft    = 0x61  // 'a'
    case moveRight   = 0x64  // 'd'
    case jump        = 0x20  // ' ' (K_SPACE)
    case crouch      = 0x63  // 'c'
    case reload      = 0x72  // 'r'
    case activate    = 0x66  // 'f' (Use / interactuar)
    case melee       = 0x76  // 'v' (Cuchillo)
    case frag        = 0x67  // 'g' (Granada letal)
    case attack      = 0xC8  // K_MOUSE1 (Disparo)
    case speed       = 0xC9  // K_MOUSE2 (Apuntar ADS)
}

/// Puente C extern para interactuar con ios_main.mm
@_silgen_name("bo1_ios_send_key")
func bo1_ios_send_key(_ key: Int32, _ down: Int32)

@_silgen_name("bo1_ios_send_mouse")
func bo1_ios_send_mouse(_ dx: Int32, _ dy: Int32)

/// Controles táctiles virtuales en pantalla y puente con GameController
struct VirtualGameControls: View {
    @State private var joystickOffset: CGSize = .zero
    @State private var isDraggingLook = false
    @State private var lastLookLocation: CGPoint = .zero

    // Estado de botones activos
    @State private var isShooting = false
    @State private var isAiming = false
    @State private var isMovingForward = false
    @State private var isMovingBack = false
    @State private var isMovingLeft = false
    @State private var isMovingRight = false

    var body: some View {
        ZStack {
            // Zona derecha: Panel táctil de rotación de cámara (Look Pad)
            HStack {
                Spacer()
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingLook {
                                    isDraggingLook = true
                                    lastLookLocation = value.location
                                } else {
                                    let dx = Int32((value.location.x - lastLookLocation.x) * 4.0)
                                    let dy = Int32((value.location.y - lastLookLocation.y) * 4.0)
                                    bo1_ios_send_mouse(dx, dy)
                                    lastLookLocation = value.location
                                }
                            }
                            .onEnded { _ in
                                isDraggingLook = false
                            }
                    )
            }

            // Esquina inferior izquierda: Joystick virtual de desplazamiento
            VStack {
                Spacer()
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 130, height: 130)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            )

                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 54, height: 54)
                            .offset(joystickOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let maxRadius: CGFloat = 50.0
                                        let translation = value.translation
                                        let distance = sqrt(translation.width * translation.width + translation.height * translation.height)
                                        if distance > maxRadius {
                                            joystickOffset = CGSize(
                                                width: (translation.width / distance) * maxRadius,
                                                height: (translation.height / distance) * maxRadius
                                            )
                                        } else {
                                            joystickOffset = translation
                                        }
                                        updateMovementFromJoystick(offset: joystickOffset)
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                            joystickOffset = .zero
                                        }
                                        stopMovement()
                                    }
                            )
                    }
                    .padding(28)
                    Spacer()
                }
            }

            // Esquina inferior derecha: Botones de acción (Disparo, Apuntar, Recarga, Acción, Cuchillo, Granada, Salto)
            VStack {
                Spacer()
                HStack(alignment: .bottom, spacing: 14) {
                    Spacer()

                    // Columna de agacharse y saltar
                    VStack(spacing: 12) {
                        actionButton(icon: "arrow.up.circle.fill", key: .jump, size: 48)
                        actionButton(icon: "figure.walk", key: .crouch, size: 48)
                    }

                    // Columna de recarga y acción / interacción
                    VStack(spacing: 12) {
                        actionButton(icon: "arrow.triangle.2.circlepath", key: .reload, size: 52)
                        actionButton(icon: "hand.tap.fill", key: .activate, size: 52)
                    }

                    // Columna de cuchillo y granada
                    VStack(spacing: 12) {
                        actionButton(icon: "flame.fill", key: .frag, size: 50)
                        actionButton(icon: "shield.righthalf.filled", key: .melee, size: 50)
                    }

                    // Columna principal: Apuntar con mira (ADS) y Disparar
                    VStack(spacing: 14) {
                        actionButton(icon: "scope", key: .speed, size: 58, tint: .cyan)
                        actionButton(icon: "target", key: .attack, size: 70, tint: .red)
                    }
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            setupPhysicalGameController()
        }
    }

    // Actualizar movimiento de WASD basado en el ángulo y radio del stick virtual
    private func updateMovementFromJoystick(offset: CGSize) {
        let forward = offset.height < -15
        let back = offset.height > 15
        let left = offset.width < -15
        let right = offset.width > 15

        if forward != isMovingForward {
            isMovingForward = forward
            bo1_ios_send_key(NativeEngineKey.moveForward.rawValue, forward ? 1 : 0)
        }
        if back != isMovingBack {
            isMovingBack = back
            bo1_ios_send_key(NativeEngineKey.moveBack.rawValue, back ? 1 : 0)
        }
        if left != isMovingLeft {
            isMovingLeft = left
            bo1_ios_send_key(NativeEngineKey.moveLeft.rawValue, left ? 1 : 0)
        }
        if right != isMovingRight {
            isMovingRight = right
            bo1_ios_send_key(NativeEngineKey.moveRight.rawValue, right ? 1 : 0)
        }
    }

    private func stopMovement() {
        if isMovingForward { isMovingForward = false; bo1_ios_send_key(NativeEngineKey.moveForward.rawValue, 0) }
        if isMovingBack    { isMovingBack = false; bo1_ios_send_key(NativeEngineKey.moveBack.rawValue, 0) }
        if isMovingLeft    { isMovingLeft = false; bo1_ios_send_key(NativeEngineKey.moveLeft.rawValue, 0) }
        if isMovingRight   { isMovingRight = false; bo1_ios_send_key(NativeEngineKey.moveRight.rawValue, 0) }
    }

    @ViewBuilder
    private func actionButton(icon: String, key: NativeEngineKey, size: CGFloat, tint: Color = .white) -> some View {
        Button(action: {}) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: size, height: size)
                    .overlay(
                        Circle().stroke(tint.opacity(0.6), lineWidth: 2)
                    )

                Image(systemName: icon)
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundColor(tint)
            }
        }
        ._onButtonGesture(pressing: { pressing in
            bo1_ios_send_key(key.rawValue, pressing ? 1 : 0)
        }, perform: {})
    }

    // Configurar mandos físicos inalámbricos (Xbox / PlayStation / MFi)
    private func setupPhysicalGameController() {
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { _ in
            for controller in GCController.controllers() {
                if let extended = controller.extendedGamepad {
                    extended.buttonA.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.jump.rawValue, pressed ? 1 : 0)
                    }
                    extended.buttonB.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.crouch.rawValue, pressed ? 1 : 0)
                    }
                    extended.buttonX.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.reload.rawValue, pressed ? 1 : 0)
                    }
                    extended.buttonY.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.activate.rawValue, pressed ? 1 : 0)
                    }
                    extended.rightTrigger.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.attack.rawValue, pressed ? 1 : 0)
                    }
                    extended.leftTrigger.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.speed.rawValue, pressed ? 1 : 0)
                    }
                    extended.rightShoulder.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.frag.rawValue, pressed ? 1 : 0)
                    }
                    extended.leftShoulder.pressedChangedHandler = { _, _, pressed in
                        bo1_ios_send_key(NativeEngineKey.melee.rawValue, pressed ? 1 : 0)
                    }
                }
            }
        }
    }
}
