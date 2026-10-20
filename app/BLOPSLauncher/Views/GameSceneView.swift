name: GameGame

import SwiftUI
import SceneKit
import GameCore

struct GameView: View {
    @EnvironmentObject var appState: AppState
    @State private var world = GameWorld(level: .kino, seed: 1234)
    @State private var lastUpdate = Date()
    @State private var scene = SCNScene()
    @State private var paused = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SceneView(
                    scene: scene,
                    pointOfView: scene.rootNode.childNode(withName: "playerCamera", recursively: false),
                    options: [.allowsCameraControl]
                )
                .onAppear { buildScene(size: geo.size) }
                .onChange(of: geo.size) { _, newSize in buildScene(size: newSize) }

                VStack {
                    HStack {
                        Spacer()
                        Button(paused ? "Resume" : "Pause") { paused.toggle() }
                            .padding(8)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Spacer()
                    HUDView(world: world)
                }
                .padding()
            }
        }
        .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
            guard !paused else { return }
            let now = Date()
            let dt = Float(now.timeIntervalSince(lastUpdate))
            lastUpdate = now
            _ = world.update(dt: dt, input: .init())
            syncScene()
        }
    }

    private func buildScene(size: CGSize) {
        scene = SCNScene()
        let cameraNode = SCNNode()
        cameraNode.name = "playerCamera"
        let cam = SCNCamera()
        cam.fieldOfView = 80
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        syncScene()
    }

    private func syncScene() {
        guard let cam = scene.rootNode.childNode(withName: "playerCamera", recursively: false) else { return }
        let p = world.player
        let yaw = Float(-Double(p.yaw)) * 180 / Double.pi
        let pitch = Float(Double(p.pitch)) * 180 / Double.pi
        cam.eulerAngles = SCNVector3(Double(pitch), Double(yaw), 0)
        cam.position = SCNVector3(p.position.x, Double(p.position.y + 1.6), Double(p.position.z))
    }
}

struct HUDView: View {
    let world: GameWorld
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("R \(world.round) - Score \(world.player.points)")
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
