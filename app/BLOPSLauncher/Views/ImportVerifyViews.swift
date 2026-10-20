import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var isPicking = false
    var body: some View {
        VStack(spacing: 12) {
            Text("Select your Call of Duty: Black Ops folder")
            Text("Only files you own. Nothing is uploaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Choose Folder") { isPicking = true }
            .fileImporter(isPresented: $isPicking, allowedContentTypes: [.folder]) { result in
                // TODO: persist bookmark, trigger verify
            }
        }
        .padding()
        .navigationTitle("Import")
    }
}

struct VerifyView: View {
    @State private var progress: Double = 0
    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
            Text("Verifying files...")
            List {
                Text("main/iw_01.iwd - OK")
                Text("zone/common/kino.ff - OK")
            }
        }
        .padding()
        .navigationTitle("Verify")
    }
}