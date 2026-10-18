import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingPicker = false
    @State private var message: String?
    @State private var isValid = false
    @State private var gameFolderURL: URL?
    @State private var folderName: String?
    @State private var hasSavedFolder = false
    @State private var isPlayingKino = false

    var body: some View {
        ZStack {
            // Fondo oscuro estilo menú Call of Duty: Black Ops
            Color(red: 0.05, green: 0.05, blue: 0.07).ignoresSafeArea()

            if isValid, let gameFolderURL {
                // Menú Principal Auténtico de Black Ops Zombies
                mainZombiesMenu(gameFolder: gameFolderURL)
            } else {
                // Pantalla limpia de selección de carpeta de juego (solo si no está vinculada)
                welcomeFolderSetup
            }
        }
        .statusBar(hidden: true)
        .fullScreenCover(isPresented: $isPlayingKino) {
            if let gameFolderURL {
                KinoGameView(gameFolder: gameFolderURL)
            }
        }
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handle(result)
        }
        .task {
            prepareFolder()
        }
    }

    // MARK: - Menú Principal Oficial de Black Ops Zombies (Landscape Fullscreen)
    @ViewBuilder
    private func mainZombiesMenu(gameFolder: URL) -> some View {
        HStack(spacing: 0) {
            // Columna Izquierda: Logo y Menú de Opciones estilo Black Ops
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CALL OF DUTY")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                        .tracking(3)

                    Text("BLACK OPS")
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .tracking(2)

                    Text("ZOMBIES")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                        .tracking(4)
                }
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 12) {
                    // Botón Principal: JUGAR KINO DER TOTEN
                    Button {
                        isPlayingKino = true
                    } label: {
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 4, height: 26)

                            Text("SOLO · KINO DER TOTEN")
                                .font(.system(size: 17, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                                .tracking(1)

                            Image(systemName: "play.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 8)
                        .padding(.trailing, 16)
                    }

                    // Botón para cambiar carpeta de juego
                    Button {
                        showingPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.caption)
                            Text("CAMBIAR CARPETA DEL JUEGO")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Pie de página discreto
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("CARPETA: \(folderName ?? "OK")")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 12)
            }
            .padding(.leading, 40)
            .frame(maxWidth: 360, alignment: .leading)

            Spacer()

            // Columna Derecha: Tarjeta / Cartel de Kino der Toten
            VStack {
                Spacer()
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.3), Color.black.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                        )
                        .frame(width: 320, height: 200)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("TEATRO DE LOS CONDENADOS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .tracking(2)

                        Text("KINO DER TOTEN")
                            .font(.system(size: 22, weight: .black, design: .serif))
                            .foregroundColor(.white)

                        Text("Berlín, Alemania. 1963.\nEnfréntate a las hordas en el teatro abandonado.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)

                        Button {
                            isPlayingKino = true
                        } label: {
                            HStack {
                                Text("INICIAR PARTIDA")
                                    .font(.system(size: 12, weight: .black))
                                Image(systemName: "arrow.right")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
                Spacer()
            }
            .padding(.trailing, 40)
        }
    }

    // MARK: - Pantalla de Configuración Inicial
    private var welcomeFolderSetup: some View {
        VStack(spacing: 16) {
            Text("CALL OF DUTY: BLACK OPS")
                .font(.system(size: 22, weight: .black, design: .serif))
                .foregroundColor(.white)
                .tracking(2)

            Text("Para jugar, selecciona la carpeta de tu copia de Black Ops 1 (que contiene la subcarpeta 'zone').")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Elegir carpeta del juego") {
                showingPicker = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.top, 8)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(isValid ? .green : .red)
                    .padding(.horizontal, 30)
            }
        }
    }

    private func prepareFolder() {
        hasSavedFolder = GameFolderBookmark.hasSavedFolder()
        if let gameFolder = GameFolderLocator.findInDocuments() {
            inspect(gameFolder, savingBookmark: false)
            return
        }
        if let url = GameFolderBookmark.restore() {
            hasSavedFolder = true
            inspect(url, savingBookmark: false)
        }
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            isValid = false
            gameFolderURL = nil
            message = "No se pudo abrir la carpeta. Vuelve a intentarlo."
        case .success(let urls):
            guard let url = urls.first else { return }
            inspect(url, savingBookmark: true)
        }
    }

    private func inspect(_ url: URL, savingBookmark: Bool) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        switch GameFolderValidator.validate(url) {
        case .valid:
            if savingBookmark {
                hasSavedFolder = GameFolderBookmark.save(url)
            }
            self.gameFolderURL = url
            self.folderName = url.lastPathComponent
            self.isValid = true
            self.message = nil
        case .notAFolder:
            isValid = false
            gameFolderURL = nil
            message = "La selección no es una carpeta."
        case .missingZoneFolder:
            isValid = false
            gameFolderURL = nil
            message = "Falta la subcarpeta zone dentro de la carpeta elegida."
        }
    }
}
