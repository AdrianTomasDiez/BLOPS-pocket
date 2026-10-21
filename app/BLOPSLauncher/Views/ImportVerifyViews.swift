import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var store: GameFileStore
    @State private var isPicking = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Import Game Files")
                .font(.title2).bold()

            Text("This app reads your legally-owned Steam copy of Call of Duty: Black Ops. No files leave your device.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let summary = store.summary {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Already imported from: \(summary.location)")
                        .font(.caption)
                    Text("\(summary.iwdCount) .iwd  ·  \(summary.ffCount) .ff  ·  \(summary.totalSizeText)")
                        .font(.caption)
                    Text("Last scan: \(summary.lastScan, style: .date) \(summary.lastScan, style: .time)")
                        .font(.caption)
                    if summary.isUsable {
                        Label("Ready to verify", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Incomplete — both main/ and zone/ required", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Primary action: scan the app's Documents folder (where Apple Devices/Finder drops files)
            Button {
                store.scanDocuments()
            } label: {
                Label(store.isScanning ? "Scanning…" : "Scan App Documents",
                      systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isScanning)

            // Alternative: pick a folder from iCloud / On My iPhone
            Button {
                isPicking = true
            } label: {
                Label("Choose Folder (iCloud / On My iPhone)",
                      systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(store.isScanning)

            if let msg = store.message {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Import")
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                store.importFolder(url)
            case .failure(let err):
                store.message = "Picker error: \(err.localizedDescription)"
            }
        }
    }
}

struct VerifyView: View {
    @EnvironmentObject var store: GameFileStore
    @EnvironmentObject var state: AppState

    @State private var progress: Double = 0
    @State private var results: [String] = []
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 12) {
            if isRunning {
                ProgressView(value: progress)
                Text("Verifying files…")
            } else if results.isEmpty {
                Text("No verification run yet.")
                    .foregroundStyle(.secondary)
            } else {
                List(results, id: \.self) { line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            if !isRunning {
                Button("Verify All Files") { runVerify() }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.summary?.isUsable != true)
            }
        }
        .padding()
        .navigationTitle("Verify")
    }

    private func runVerify() {
        guard let folder = store.summary else { return }
        isRunning = true
        progress = 0
        results = []

        // For now just a fast size/metadata check; real SHA-256 will come from the C++ engine via Swift bridging.
        // We run it on background to keep UI responsive.
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let enumerator = FileManager.default.enumerator(at: docs,
                                                            includingPropertiesForKeys: keys,
                                                            options: [.skipsHiddenFiles])
            var count = 0
            var ok = 0
            var bad = 0

            while let file = enumerator?.nextObject() as? URL {
                guard let values = try? file.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }
                let ext = file.pathExtension.lowercased()
                guard ext == "iwd" || ext == "ff" else { continue }
                count += 1
                if let sz = values.fileSize, sz > 0 {
                    ok += 1
                    let rel = file.path.replacingOccurrences(of: docs.path, with: "")
                    DispatchQueue.main.async {
                        self.results.append("✓ \(rel)  (\(ByteCountFormatter.string(fromByteCount: Int64(sz), countStyle: .file)))")
                    }
                } else {
                    bad += 1
                    let rel = file.path.replacingOccurrences(of: docs.path, with: "")
                    DispatchQueue.main.async {
                        self.results.append("✗ \(rel)  (empty or unreadable)")
                    }
                }
            }

            DispatchQueue.main.async {
                self.isRunning = false
                self.results.insert("Verified \(ok)/\(count) files  ·  \(bad) problems", at: 0)
                self.state.isVerified = (bad == 0 && count > 0)
                self.state.installationStatus = bad == 0 ? "Verified — ready to play" : "Issues found"
            }
        }
    }
}