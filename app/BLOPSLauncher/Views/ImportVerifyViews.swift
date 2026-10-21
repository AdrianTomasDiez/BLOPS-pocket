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

                Text("Choose the folder on your iPhone that contains the `main` and `zone` folders from your Steam copy. Nothing leaves your device.")
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

                if let summary = store.summary {
                    Button {
                        store.rescanSavedFolder()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text(store.isScanning ? "Escaneando…" : "Volver a escanear la carpeta importada")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.isScanning)
                }

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
                                .font(.caption2)
                        } else {
                            Label("Faltan carpetas main o zone", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption2)
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

struct VerifyView: View {
    @EnvironmentObject var store: GameFileStore
    @EnvironmentObject var state: AppState

    @State private var report: VerifyReport?
    @State private var showOnlyProblems = false

    var body: some View {
        VStack(spacing: 12) {
            if store.isVerifying {
                ProgressView()
                Text("Verificando \(store.files.count) archivos…")
                    .foregroundStyle(.secondary)
            } else if let report {
                VStack(spacing: 10) {
                    Text("Verificados \(report.ok)/\(report.checked) archivos  ·  \(report.problems.count) problemas")
                        .font(.headline)
                    if report.isValid {
                        Label("Todo correcto", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Revisar problemas", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    if !report.problems.isEmpty {
                        Toggle("Solo problemas", isOn: $showOnlyProblems)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                    List(problemList(report), id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .listStyle(.plain)
                }
            } else {
                Text("Pulsa \"Verify All Files\" para comprobar la carpeta importada.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !store.isVerifying {
                Button("Verify All Files") { runVerify() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.files.isEmpty)
            }
        }
        .padding()
        .navigationTitle("Verify")
    }

    private func problemList(_ report: VerifyReport) -> [String] {
        if showOnlyProblems { return report.problems }
        return report.problems.isEmpty ? ["Sin problemas detectados."] : report.problems
    }

    private func runVerify() {
        store.verify { result in
            report = result
            state.isVerified = result.isValid
            state.installationStatus = result.isValid
                ? "Verified — ready to play"
                : "Verification issues found"
        }
    }
}
