import SwiftUI

struct LoadingView: View {
    let map: String
    @EnvironmentObject var state: AppState
    @State private var progress: Double = 0
    @State private var done = false

    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
            Text(done ? "Ready" : "Loading \(map)...")
            if !done {
                Text("Preparing level, weapons and zombie round…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Loading")
        .navigationBarBackButtonHidden(true)
        .onAppear { run() }
    }

    private func run() {
        guard !done else { return }
        done = true
        // Simulated load so the transition is visible; the level data is local.
        Task { @MainActor in
            for step in stride(from: 0.0, through: 1.0, by: 0.1) {
                try? await Task.sleep(nanoseconds: 90_000_000)
                progress = step
            }
            state.path.append(Route.game(map))
        }
    }
}

struct PauseOverlay: View {
    @Binding var isPaused: Bool
    var body: some View {
        Color.black.opacity(0.6).ignoresSafeArea()
        VStack(spacing: 12) {
            Text("Paused").font(.title).foregroundStyle(.white)
            Button("Resume") { isPaused = false }
            Button("Quit") { }
        }
    }
}

struct GameOverView: View {
    let round: Int
    let score: Int
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 12) {
            Text("Game Over")
                .font(.title)
            Text("You survived \(round) rounds")
            Text("Score: \(score)")
            Button("Restart") {
                state.path.removeLast(state.path.count)
                state.path.append(Route.mapSelect)
            }
            Button("Main Menu") {
                state.path.removeLast(state.path.count)
            }
        }
        .padding()
        .navigationTitle("Game Over")
    }
}

struct MissingFilesView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 12) {
            Text("Missing or invalid game files")
            Text("Import a verified copy of Call of Duty: Black Ops.")
                .font(.caption)
            Button("Import") {
                state.path.removeLast()
                state.path.append(Route.importFiles)
            }
            Button("Back") {
                state.path.removeLast()
            }
        }
        .padding()
        .navigationTitle("Missing Files")
    }
}