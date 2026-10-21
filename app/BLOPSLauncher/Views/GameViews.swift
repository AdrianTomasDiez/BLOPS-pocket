import SwiftUI

struct LoadingView: View {
    let map: String
    @State private var progress: Double = 0
    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
            Text("Loading \(map)...")
        }
        .padding()
        .navigationTitle("Loading")
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
    var body: some View {
        VStack(spacing: 12) {
            Text("Game Over")
                .font(.title)
            Text("You survived \(round) rounds")
            Text("Score: \(score)")
            Button("Restart") { }
            Button("Main Menu") { }
        }
        .padding()
        .navigationTitle("Game Over")
    }
}

struct MissingFilesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Missing or invalid game files")
            Text("Import a verified copy of Call of Duty: Black Ops.")
                .font(.caption)
            Button("Import") { }
        }
        .padding()
        .navigationTitle("Missing Files")
    }
}
