import SwiftUI

struct GameView: View {
    let map: String
    @EnvironmentObject var appState: AppState
    @State private var world: GameWorld?
    @State private var paused = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let w = world {
                VStack(spacing: 16) {
                    Text("Map: \(map)")
                        .font(.title2).bold()
                        .foregroundStyle(.white)

                    Text("Round \(w.round)  |  Score \(w.player.points)")
                        .font(.headline)
                        .foregroundStyle(.green)

                    Text("HP: \(Int(w.player.health)) / \(Int(w.player.maxHealth))")
                        .font(.title3)
                        .foregroundStyle(w.player.health > 25 ? .white : .red)

                    if let weapon = w.player.currentWeapon {
                        Text("Ammo: \(weapon.mag) / \(weapon.reserve)  •  \(weapon.displayName)")
                            .foregroundStyle(.cyan)
                    }

                    Text("Zombies alive: \(w.zombies.filter { !$0.isDying }.count)")
                        .foregroundStyle(.orange)

                    Spacer()

                    VStack(spacing: 8) {
                        HStack {
                            Spacer()
                            Button(paused ? "Resume" : "Pause") { paused.toggle() }
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding()
            } else {
                Text("Loading game world...")
                    .foregroundStyle(.white)
            }
        }
        .navigationTitle(map)
        .onAppear {
            if world == nil {
                world = GameWorld(level: .kino, seed: 1234)
            }
        }
        .onReceive(Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()) { _ in
            guard !paused, var w = world else { return }
            let dt: Float = 1.0 / 60.0
            _ = w.update(dt: dt, input: PlayerInput())
            world = w
        }
    }
}

// Needed to make the import compile without GameCore package
typealias GameWorld = GameCore_GameWorld
typealias PlayerInput = GameCore_PlayerInput

// Placeholder types to satisfy compiler when GameCore is not linked.
struct GameCore_GameWorld {
    var round = 1
    var player = GameCore_Player()
    var zombies: [GameCore_Zombie] = []
    func update(dt: Float, input: GameCore_PlayerInput) -> [GameCore_Event] { return [] }
}

struct GameCore_Player {
    var health: Float = 100
    var maxHealth: Float = 100
    var points = 0
    var currentWeapon: GameCore_WeaponState?
}

struct GameCore_WeaponState {
    var mag = 8
    var reserve = 80
    var displayName = "M1911"
}

struct GameCore_Zombie {
    var isDying = false
}

struct GameCore_PlayerInput { }

struct GameCore_Event { }