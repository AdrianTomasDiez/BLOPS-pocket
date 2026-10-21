import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var store: GameFileStore

    var body: some View {
        VStack(spacing: 16) {
            Text("BO1 Zombies Launcher")
                .font(.title)
            StatusCard(status: state.installationStatus, verified: state.isVerified)
            if store.summary != nil {
                Button("Verify Files") { state.path.append(Route.verify) }
                Button("Play") { state.path.append(Route.mapSelect) }
                    .disabled(!state.isVerified)
            } else {
                Button("Import Game Files") { state.path.append(Route.importFiles) }
            }
            Button("Settings") { state.path.append(Route.settings) }
            Button("About") { state.path.append(Route.about) }
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