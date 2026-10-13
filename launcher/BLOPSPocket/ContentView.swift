import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingPicker = false
    @State private var message: String?
    @State private var isValid = false
    @State private var catalog: ZoneCatalog?
    @State private var folderName: String?
    @State private var origin: FolderOrigin?
    @State private var hasSavedFolder = false

    /// De dónde sale la carpeta que se está leyendo.
    private enum FolderOrigin {
        /// Copia dentro del contenedor de la app (vía recomendada).
        case appDocuments
        /// Carpeta elegida en Archivos y recordada con un bookmark.
        case external

        var description: String {
            switch self {
            case .appDocuments: return "Copia dentro de la app"
            case .external: return "Carpeta elegida en Archivos"
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("BLOPS pocket")
                .font(.largeTitle)

            if let folderName, let origin {
                VStack(spacing: 2) {
                    Text("Carpeta del juego: \(folderName)")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Text(origin.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else {
                Text("Copia la carpeta del juego (la que contiene la subcarpeta zone) en Archivos → En mi iPhone → BLOPS pocket → Games, o elige otra carpeta con el botón.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Elegir otra carpeta del juego") {
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

            if hasSavedFolder {
                Button("Olvidar la carpeta guardada") {
                    forget()
                }
                .font(.footnote)
            }

            Text("Este lanzador no incluye ni distribuye archivos del juego: solo lee la copia que tú posees. Si desinstalas la app, se borra la copia que hayas puesto dentro.")
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
        .task {
            prepareFolder()
        }
    }

    /// Al abrir: primero la copia dentro de la app, después la carpeta recordada.
    private func prepareFolder() {
        hasSavedFolder = GameFolderBookmark.hasSavedFolder()

        if let gameFolder = GameFolderLocator.findInDocuments() {
            inspect(gameFolder, origin: .appDocuments, savingBookmark: false)
            return
        }

        restoreSavedFolder()
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            isValid = false
            catalog = nil
            message = "No se pudo abrir la carpeta. Vuelve a intentarlo."
        case .success(let urls):
            guard let url = urls.first else { return }
            inspect(url, origin: .external, savingBookmark: true)
        }
    }

    /// Recupera la carpeta elegida en Archivos una vez anterior.
    private func restoreSavedFolder() {
        guard let url = GameFolderBookmark.restore() else { return }
        hasSavedFolder = true
        inspect(url, origin: .external, savingBookmark: false)
    }

    /// Valida la carpeta y construye el catálogo. Todo el acceso al disco ocurre
    /// dentro del ámbito de seguridad de la URL (para las carpetas externas).
    private func inspect(_ url: URL, origin: FolderOrigin, savingBookmark: Bool) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        switch GameFolderValidator.validate(url) {
        case .valid:
            if savingBookmark {
                hasSavedFolder = GameFolderBookmark.save(url)
            }
            let catalog = ZoneCatalog.build(in: url)
            self.catalog = catalog
            self.folderName = url.lastPathComponent
            self.origin = origin
            isValid = !catalog.entries.isEmpty
            message = summary(for: catalog)
        case .notAFolder:
            isValid = false
            catalog = nil
            message = "La selección no es una carpeta."
        case .missingZoneFolder:
            isValid = false
            catalog = nil
            message = "Falta la subcarpeta zone dentro de la carpeta elegida. Copia la carpeta del juego completa."
        }
    }

    private func forget() {
        GameFolderBookmark.clear()
        hasSavedFolder = false
        guard origin == .external else {
            message = "Se olvidó la carpeta externa guardada."
            return
        }
        catalog = nil
        folderName = nil
        origin = nil
        isValid = false
        message = "Se olvidó la carpeta guardada. Elige de nuevo la carpeta del juego."
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
