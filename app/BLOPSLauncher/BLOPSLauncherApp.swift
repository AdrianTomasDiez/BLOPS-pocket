import SwiftUI

@main
struct BLOPSLauncherApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

final class AppState: ObservableObject {
    @Published var installationStatus: String = "Not verified"
    @Published var isVerified: Bool = false
    @Published var selectedMap: String? = "kino"
}