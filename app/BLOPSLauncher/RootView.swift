import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .importFiles: ImportView()
                    case .verify: VerifyView()
                    case .settings: SettingsView()
                    case .about: AboutView()
                    case .mapSelect: MapSelectView()
                    case .loading(let map): LoadingView(map: map)
                    case .game(let map): GameView(map: map)
                    case .gameOver(let round, let score): GameOverView(round: round, score: score)
                    case .missing: MissingFilesView()
                    }
                }
        }
    }
}

enum Route: Hashable {
    case importFiles, verify, settings, about, mapSelect
    case loading(String), game(String), gameOver(Int, Int), missing
}