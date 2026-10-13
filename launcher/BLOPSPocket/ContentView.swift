import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingPicker = false
    @State private var message: String?
    @State private var isValid = false

    var body: some View {
        VStack(spacing: 16) {
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
        }
        .padding()
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
            message = "No se pudo abrir la carpeta. Vuelve a intentarlo."
        case .success(let urls):
            guard let url = urls.first else { return }
            // Las URLs de Archivos requieren acceso de seguridad explícito.
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            switch GameFolderValidator.validate(url) {
            case .valid:
                isValid = true
                message = "Carpeta válida: se encontró la subcarpeta zone."
            case .notAFolder:
                isValid = false
                message = "La selección no es una carpeta."
            case .missingZoneFolder:
                isValid = false
                message = "Falta la subcarpeta zone dentro de la carpeta elegida."
            }
        }
    }
}
