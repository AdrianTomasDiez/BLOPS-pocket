import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingPicker = false
    @State private var message: String?
    @State private var isValid = false
    @State private var catalog: ZoneCatalog?

    var body: some View {
        VStack(spacing: 12) {
            Text("BLOPS pocket")
                .font(.largeTitle)

            Text("Elige la carpeta del juego que copiaste en Archivos. Debe contener una subcarpeta zone.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Elegir carpeta del juego") {
                showingPicker = true
            }
            .buttonStyle(.borderedProminent)

            if let message {
                Text(message)
                    .foregroundColor(isValid ? .green : .red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let catalog {
                ZoneCatalogView(catalog: catalog)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer()
            }

            Text("Este lanzador no incluye ni distribuye archivos del juego: solo lee la copia que tú posees.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top)
        .fileImporter(
            isPresented: $showingPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handle(result)
        }
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            isValid = false
            catalog = nil
            message = "No se pudo abrir la carpeta. Vuelve a intentarlo."
        case .success(let urls):
            guard let url = urls.first else { return }
            // Las URLs de Archivos requieren acceso de seguridad explícito.
            // Todo lo que lea del disco debe hacerse dentro de este bloque.
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            switch GameFolderValidator.validate(url) {
            case .valid:
                let catalog = ZoneCatalog.build(in: url)
                self.catalog = catalog
                isValid = !catalog.entries.isEmpty
                message = summary(for: catalog)
            case .notAFolder:
                isValid = false
                catalog = nil
                message = "La selección no es una carpeta."
            case .missingZoneFolder:
                isValid = false
                catalog = nil
                message = "Falta la subcarpeta zone dentro de la carpeta elegida."
            }
        }
    }

    private func summary(for catalog: ZoneCatalog) -> String {
        guard !catalog.entries.isEmpty else {
            return "Se encontró la carpeta zone, pero no contiene ningún archivo .ff."
        }
        var text = "\(catalog.entries.count) zonas encontradas · \(catalog.totalDescription)"
        if !catalog.unsupported.isEmpty {
            text += "\n\(catalog.unsupported.count) con una versión distinta a la esperada (0x1D9)."
        }
        return text
    }
}

/// Inventario de zonas: resumen y listado por grupo.
private struct ZoneCatalogView: View {
    let catalog: ZoneCatalog

    var body: some View {
        List {
            Section {
                row("Zonas .ff", "\(catalog.entries.count)")
                row("Tamaño en disco", catalog.totalDescription)
                row("Zombies", "\(catalog.count(of: .zombies)) · \(size(of: .zombies))")
                if !catalog.unsupported.isEmpty {
                    row("Versión inesperada", "\(catalog.unsupported.count)")
                }
            } header: {
                Text("Resumen")
            } footer: {
                Text("Solo se leen los 12 bytes de cabecera de cada archivo: no se descomprime ni se carga nada del juego.")
            }

            ForEach(catalog.presentGroups, id: \.self) { group in
                Section(group.displayName) {
                    ForEach(entries(in: group), id: \.relativePath) { entry in
                        HStack {
                            Text(entry.name)
                                .font(.subheadline)
                            Spacer()
                            Text(sizeLabel(for: entry))
                                .font(.caption)
                                .foregroundColor(entry.isSupported ? .secondary : .red)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func entries(in group: ZoneGroup) -> [ZoneEntry] {
        catalog.entries.filter { $0.group == group }
    }

    /// Tamaño en disco, o la versión leída si el archivo no es de BO1 PC.
    private func sizeLabel(for entry: ZoneEntry) -> String {
        guard entry.isSupported else {
            let version = entry.header?.versionDescription ?? "sin cabecera"
            return "versión \(version)"
        }
        return entry.sizeDescription
    }

    private func size(of group: ZoneGroup) -> String {
        ByteCountFormatter.string(fromByteCount: catalog.bytes(of: group), countStyle: .file)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
