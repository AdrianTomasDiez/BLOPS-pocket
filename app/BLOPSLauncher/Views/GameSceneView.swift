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

    var body: some View {
        GeometryReader { _ in
            ZStack {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: "playerCamera", recursively: false),
                    options: []
                )
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        Button(paused ? "Resume" : "Pause") { paused.toggle() }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Spacer()
                    HUDView(world: world)
                }
                .padding()
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
            handle(events)
            syncScene()
        }
    }

    // Touch input is wired in the next milestone; for now the player stands still
    // and zombies approach, which already exercises the whole simulation.
    private var currentInput: PlayerInput {
        var input = PlayerInput()
        input.firing = false
        return input
    }

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .gameOver(_, _):
                break
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

        syncScene()
    }

    private func syncScene() {
        guard let cam = scene.rootNode.childNode(withName: "playerCamera", recursively: false) else { return }
        let p = world.player
        let yawDeg = Float(-p.yaw) * 180.0 / Float.pi
        let pitchDeg = Float(p.pitch) * 180.0 / Float.pi
        cam.eulerAngles = SCNVector3(pitchDeg, yawDeg, 0)
        cam.position = SCNVector3(Float(p.position.x), Float(p.position.y) + 1.6, Float(p.position.z))
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
