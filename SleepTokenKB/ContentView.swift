import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sleep Token Keyboard")
                            .font(.title2.weight(.bold))
                        Text("Ritual alphabet keys for iOS. Symbols on the keys, Latin letters in your messages.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section("Get started") {
                    NavigationLink {
                        EnableKeyboardView()
                    } label: {
                        Label("Enable the keyboard", systemImage: "keyboard")
                    }

                    NavigationLink {
                        AlphabetChartView()
                    } label: {
                        Label("Alphabet chart", systemImage: "square.grid.3x3")
                    }
                }

                Section("Defaults for the keyboard") {
                    LayoutPicker()
                    Toggle("Haptic feedback", isOn: hapticsBinding)
                    Toggle("Show Latin hints on keys", isOn: hintsBinding)
                }

                Section {
                    Text("Unofficial fan project. Not affiliated with, endorsed by, or connected to Sleep Token or their rights holders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sleep Token KB")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { KeyboardPreferences.hapticsEnabled },
            set: { KeyboardPreferences.hapticsEnabled = $0 }
        )
    }

    private var hintsBinding: Binding<Bool> {
        Binding(
            get: { KeyboardPreferences.showLatinHints },
            set: { KeyboardPreferences.showLatinHints = $0 }
        )
    }
}

private struct LayoutPicker: View {
    @State private var mode: LayoutMode = KeyboardPreferences.layoutMode

    var body: some View {
        Picker("Default layout", selection: $mode) {
            ForEach(LayoutMode.allCases) { m in
                Text(m.title).tag(m)
            }
        }
        .onChange(of: mode) { _, newValue in
            KeyboardPreferences.layoutMode = newValue
        }
        .onAppear {
            mode = KeyboardPreferences.layoutMode
        }
    }
}

#Preview {
    ContentView()
}
