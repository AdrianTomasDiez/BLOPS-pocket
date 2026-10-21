import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: GameFileStore
    @State private var showImport = false

    var body: some View {
        VStack(spacing: 16) {
            Text("BO1 Zombies Launcher")
                .font(.title)
            StatusCard(status: state.installationStatus, verified: state.isVerified)
            if store.summary != nil {
                Button("Verify Files") { state.path.push(Route.verify) }
                Button("Play") { state.path.push(Route.mapSelect) }
                    .disabled(!state.isVerified)
            } else {
                Button("Import Game Files") { state.path.push(Route.importFiles) }
            }
            Button("Settings") { state.path.push(Route.settings) }
            Button("About") { state.path.push(Route.about) }
        }
        .padding()
        .navigationTitle("Home")
    }
}

struct StatusCard: View {
    let status: String
    let verified: Bool
    var body: some View {
        VStack(alignment: .leading) {
            Text("Status: \(status)")
            Text(verified ? "Ready to play" : "Import and verify your owned game files")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}