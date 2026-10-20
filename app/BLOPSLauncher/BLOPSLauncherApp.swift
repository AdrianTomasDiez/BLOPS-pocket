import SwiftUI

final class AppState: ObservableObject {
    @Published var installationStatus: String = "No folder scanned"
    @Published var isVerified: Bool = false
    @Published var selectedMap: String? = "kino"

    @Published var path = NavigationPath()
}

final class AppContainer: ObservableObject {
    @Published var fileStore = GameFileStore()
    @Published var profileService = ProfileService()
    @Published var appState = AppState()

    init() {}
}

@main
struct BLOPSLauncherApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.appState)
                .environmentObject(container.fileStore)
                .environmentObject(container.profileService)
        }
    }
}
