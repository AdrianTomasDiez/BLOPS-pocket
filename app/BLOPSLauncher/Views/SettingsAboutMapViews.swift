import SwiftUI

struct SettingsView: View {
    @State private var sensitivity: Double = 1.0
    @State private var quality: String = "medium"
    @State private var master: Double = 1.0
    var body: some View {
        Form {
            Section("Controls") {
                Slider(value: $sensitivity, in: 0.5...2.0) { Text("Sensitivity") }
            }
            Section("Graphics") {
                Picker("Quality", selection: $quality) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
            }
            Section("Audio") {
                Slider(value: $master, in: 0...1) { Text("Master") }
            }
        }
        .navigationTitle("Settings")
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.title)
                Text("This launcher reads game files you own. It does not include or distribute Activision content.")
                Text("Clean-room reimplementation. Trademarks belong to their owners.")
            }
            .padding()
        }
        .navigationTitle("About")
    }
}

struct MapSelectView: View {
    @EnvironmentObject var state: AppState
    let maps = [MapInfo(id: "kino", name: "Kino der Toten", supported: true)]
    var body: some View {
        List(maps) { m in
            Button {
                state.selectedMap = m.id
                state.path.append(Route.loading(m.id))
            } label: {
                HStack {
                    Text(m.name)
                    Spacer()
                    if m.supported {
                        Text("Supported")
                            .foregroundStyle(.green)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!m.supported)
        }
        .navigationTitle("Select Map")
    }
}