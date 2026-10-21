import SwiftUI
import SceneKit

struct GameView: View {
    let map: String
    @EnvironmentObject var appState: AppState
    @State private var world = GameWorld(level: LevelSpec.kino, seed: 1234)
    @State private var scene = SCNScene()
    @State private var paused = false
    @State private var didBuild = false
    @State private var lastUpdate = Date()
    @State private var move = CGPoint.zero
    @State private var lookDelta = CGPoint.zero
    @State private var lookPrev = CGPoint.zero
    @State private var isFiring = false
    @State private var gameOverTriggered = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: "playerCamera", recursively: false),
                    options: []
                )
                .ignoresSafeArea()

                // Left half: virtual stick to move. Right half: drag to look.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if value.startLocation.x < geo.size.width * 0.45 {
                                    move = CGPoint(x: value.translation.width, y: value.translation.height)
                                } else {
                                    // Accumulate the incremental delta so the camera
                                    // follows the finger 1:1 without double counting.
                                    lookDelta.x += value.translation.width - lookPrev.x
                                    lookDelta.y += value.translation.height - lookPrev.y
                                    lookPrev = CGPoint(x: value.translation.width, y: value.translation.height)
                                }
                            }
                            .onEnded { value in
                                if value.startLocation.x < geo.size.width * 0.45 {
                                    move = .zero
                                } else {
                                    lookDelta = .zero
                                    lookPrev = .zero
                                }
                            }
                    )

                VStack {
                    HStack {
                        Spacer()
                        Button(paused ? "Resume" : "Pause") { paused.toggle() }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        MoveStick(value: $move)
                            .frame(width: 130, height: 130)
                        Spacer()
                        VStack(spacing: 12) {
                            Button {
                                isFiring = true
                            } label: {
                                Image(systemName: "scope")
                                    .font(.system(size: 34, weight: .bold))
                                    .frame(width: 84, height: 84)
                                    .background(Color.red.opacity(0.55))
                                    .foregroundStyle(.white)
                                    .clipShape(Circle())
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in isFiring = true }
                                    .onEnded { _ in isFiring = false }
                            )
                            Button {
                                world.player.currentWeaponIndex =
                                    (world.player.currentWeaponIndex + 1) % max(world.player.weapons.count, 1)
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 20, weight: .bold))
                                    .frame(width: 54, height: 54)
                                    .background(.thinMaterial)
                                    .foregroundStyle(.white)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    HUDView(world: world)
                }
                .padding()
                .allowsHitTesting(true)

                if paused {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Text("Paused").font(.title).foregroundStyle(.white)
                        Button("Resume") { paused = false }
                            .buttonStyle(.borderedProminent)
                        Button("Quit to menu") {
                            appState.path.removeLast(appState.path.count)
                        }
                    }
                }
            }
        }
        .onAppear {
            if !didBuild {
                didBuild = true
                buildScene()
            }
        }
        .onReceive(Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()) { _ in
            guard !paused else { return }
            let now = Date()
            let dt = Float(now.timeIntervalSince(lastUpdate))
            lastUpdate = now
            let events = world.update(dt: dt, input: currentInput)
            // Consume the look delta once per frame
            lookDelta = .zero
            handle(events)
            syncScene()
        }
    }

    // Touch input is wired in the next milestone; for now the player stands still
    // and zombies approach, which already exercises the whole simulation.
    private var currentInput: PlayerInput {
        var input = PlayerInput()
        input.moveX = Float(move.x / 60.0)
        input.moveZ = Float(-move.y / 60.0)
        input.lookDX = Float(lookDelta.x) * 0.05
        input.lookDY = Float(-lookDelta.y) * 0.05
        input.firing = isFiring
        input.sprint = input.moveX != 0 || input.moveZ != 0
        return input
    }

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .gameOver(let score, let round):
                guard !gameOverTriggered else { break }
                gameOverTriggered = true
                paused = true
                appState.path.append(Route.gameOver(round, score))
            default:
                break
            }
        }
    }

    private func buildScene() {
        scene = SCNScene()
        scene.background.contents = UIColor.black

        let cameraNode = SCNNode()
        cameraNode.name = "playerCamera"
        let cam = SCNCamera()
        cam.fieldOfView = 85
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 900
        ambient.light?.color = UIColor(white: 0.55, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        for room in world.level.rooms {
            let floor = SCNBox(width: CGFloat(room.max.x - room.min.x),
                                height: 0.1,
                                length: CGFloat(room.max.z - room.min.z),
                                chamferRadius: 0)
            floor.firstMaterial?.diffuse.contents = UIColor(white: 0.18, alpha: 1)
            let node = SCNNode(geometry: floor)
            node.position = SCNVector3(Float((room.min.x + room.max.x) / 2), 0,
                                       Float((room.min.z + room.max.z) / 2))
            scene.rootNode.addChildNode(node)
        }

        for box in world.level.wallBoxes() {
            let geometry = SCNBox(width: CGFloat(box.max.x - box.min.x),
                                  height: CGFloat(box.max.y - box.min.y),
                                  length: CGFloat(box.max.z - box.min.z),
                                  chamferRadius: 0)
            geometry.firstMaterial?.diffuse.contents = UIColor(white: 0.35, alpha: 1)
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(Float((box.min.x + box.max.x) / 2),
                                       Float((box.min.y + box.max.y) / 2),
                                       Float((box.min.z + box.max.z) / 2))
            scene.rootNode.addChildNode(node)
        }

        for prop in world.level.props {
            let geometry = SCNBox(width: CGFloat(prop.max.x - prop.min.x),
                                  height: CGFloat(prop.max.y - prop.min.y),
                                  length: CGFloat(prop.max.z - prop.min.z),
                                  chamferRadius: 0.05)
            geometry.firstMaterial?.diffuse.contents = UIColor(white: 0.28, alpha: 1)
            let node = SCNNode(geometry: geometry)
            node.position = SCNVector3(Float((prop.min.x + prop.max.x) / 2),
                                       Float((prop.min.y + prop.max.y) / 2),
                                       Float((prop.min.z + prop.max.z) / 2))
            scene.rootNode.addChildNode(node)
        }

        for door in world.level.doors {
            let size = door.alongZ
                ? CGSize(width: CGFloat(0.35), height: 4)
                : CGSize(width: CGFloat(door.width), height: 4)
            let geometry = SCNBox(width: CGFloat(size.width),
                                  height: CGFloat(size.height),
                                  length: door.alongZ ? CGFloat(door.width) : CGFloat(0.35),
                                  chamferRadius: 0)
            geometry.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.35, blue: 0.35, alpha: 0.25)
            let node = SCNNode(geometry: geometry)
            node.name = "door_\(door.id)"
            node.position = SCNVector3(door.center.x, 2, door.center.z)
            scene.rootNode.addChildNode(node)
        }

        syncScene()
    }

    private func syncScene() {
        guard let cam = scene.rootNode.childNode(withName: "playerCamera", recursively: false) else { return }
        let p = world.player
        let yawDeg = Float(-p.yaw) * 180.0 / Float.pi
        let pitchDeg = Float(p.pitch) * 180.0 / Float.pi
        cam.eulerAngles = SCNVector3(pitchDeg, yawDeg, 0)
        cam.position = SCNVector3(Float(p.position.x), Float(p.position.y) + 1.6, Float(p.position.z))

        syncZombies()
        syncDoors()
    }

    /// Creates/updates/removes one capsule per zombie so the fight is visible.
    private func syncZombies() {
        let container = scene.rootNode.childNode(withName: "zombies", recursively: false)
            ?? makeContainer("zombies")
        var seen = Set<Int>()
        for zombie in world.zombies {
            seen.insert(zombie.id)
            let name = "z\(zombie.id)"
            let node = container.childNode(withName: name, recursively: false) ?? makeZombie(zombie)
            node.position = SCNVector3(Float(zombie.position.x),
                                       Float(zombie.position.y) + 0.9,
                                       Float(zombie.position.z))
            node.isHidden = zombie.isDying
            if let geo = node.geometry as? SCNCapsule {
                let healthRatio = max(0.05, CGFloat(zombie.health / max(zombie.maxHealth, 1)))
                geo.height = 1.8
                geo.capRadius = 0.35
                geo.firstMaterial?.diffuse.contents = UIColor(
                    red: 0.35 * healthRatio + 0.25,
                    green: 0.55 * healthRatio,
                    blue: 0.30,
                    alpha: 1)
            }
        }
        for child in container.childNodes {
            let zid = Int((child.name ?? "").dropFirst()) ?? -1
            if !seen.contains(zid) { child.removeFromParentNode() }
        }
    }

    private func makeContainer(_ name: String) -> SCNNode {
        let node = SCNNode()
        node.name = name
        scene.rootNode.addChildNode(node)
        return node
    }

    private func makeZombie(_ zombie: Zombie) -> SCNNode {
        let geo = SCNCapsule(capRadius: 0.35, height: 1.8)
        geo.firstMaterial?.diffuse.contents = UIColor(red: 0.35, green: 0.55, blue: 0.30, alpha: 1)
        let node = SCNNode(geometry: geo)
        node.name = "z\(zombie.id)"
        scene.rootNode.childNode(withName: "zombies", recursively: false)?.addChildNode(node)
        return node
    }

    private func syncDoors() {
        for door in world.level.doors {
            guard let node = scene.rootNode.childNode(withName: "door_\(door.id)", recursively: false) else { continue }
            node.isHidden = world.doorsOpen.contains(door.id)
        }
    }
}

struct MoveStick: View {
    @Binding var value: CGPoint
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.2))
            Circle().fill(Color.white.opacity(0.1))
                .frame(width: 60, height: 60)
            Circle().fill(Color.white)
                .frame(width: 30, height: 30)
                .offset(x: value.x, y: value.y)
        }
    }
}

struct HUDView: View {
    let world: GameWorld
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("R \(world.round)  -  Score \(world.player.points)")
                .font(.caption).bold()
            Text("HP \(Int(world.player.health)) / \(Int(world.player.maxHealth))")
                .font(.caption)
            if let w = world.player.currentWeapon {
                Text("Ammo \(w.mag)/\(w.reserve)  \(w.displayName)")
                    .font(.caption)
            }
            Text("Zombies: \(world.zombies.filter { !$0.isDying }.count)")
                .font(.caption)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
