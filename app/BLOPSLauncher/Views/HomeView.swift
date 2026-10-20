import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @State private var showImport = false

    var body: some View {
        VStack(spacing: 16) {
            Text("BO1 Zombies Launcher")
                .font(.title)
            StatusCard(status: state.installationStatus, verified: state.isVerified)
            Button("Import Game Files") { showImport = true }
                .buttonStyle(.borderedProminent)
            Button("Verify Files") { /* navigate verify */ }
            Button("Play") { /* navigate mapSelect */ }
                .disabled(!state.isVerified)
            Button("Settings") { }
            Button("About") { }
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