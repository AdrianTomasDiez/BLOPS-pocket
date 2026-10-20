import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var store: GameFileStore
    @State private var isPicking = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Import Game Files")
                    .font(.largeTitle).bold()

                Text("Elegí la carpeta de tu iPhone que contenga las carpetas `main` y `zone` de tu copia de Steam. Nothing leaves your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Botón principal: elegir carpeta desde Files (On My iPhone / iCloud Drive)
                Button {
                    isPicking = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.gearshape")
                        Text("Seleccionar carpeta para escanear")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isScanning)

                // Secundario: escanear Documents de la app (si ya copiaste por Finder/Apple Devices)
                Button {
                    store.scanDocuments()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text(store.isScanning ? "Escaneando…" : "Escanear Documents de la app")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.bordered)
                .disabled(store.isScanning)

                // Resultado del último escaneo
                if let summary = store.summary {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Encontrado en: \(summary.location)")
                            .font(.caption2).foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Label("\(summary.iwdCount) .iwd", systemImage: "cube.fill")
                            Label("\(summary.ffCount) .ff", systemImage: "cube.fill")
                            Label(summary.totalSizeText, systemImage: "externaldrive")
                        }
                        .font(.caption)
                        if summary.isUsable {
                            Label("Listo para verificar", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption3)
                        } else {
                            Label("Faltan carpetas main o zone", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption3)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let msg = store.message {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Import")
        .fileImporter(
            isPresented: $isPicking,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                store.importFolder(url)
            case .failure(let err):
                store.message = "Error al elegir carpeta: \(err.localizedDescription)"
            }
        }
    }
}
