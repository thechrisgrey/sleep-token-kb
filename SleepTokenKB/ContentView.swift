import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sleep Token Keyboard")
                            .font(.title2.weight(.bold))
                        Text("Keep it simple: type English everywhere. Want real runes? Compose in Rune Pad and copy as an image.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section("Two ways to engage") {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System keyboard").font(.body.weight(.semibold))
                            Text("Rune or ABC keycaps. Always inserts normal English — works in Messages, Reminders, Notes, everywhere.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "keyboard")
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rune Pad").font(.body.weight(.semibold))
                            Text("Spell with vertical runes, then Copy Image and paste into any app that accepts pictures.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                Section("Get started") {
                    NavigationLink {
                        EnableKeyboardView()
                    } label: {
                        Label("Enable the keyboard", systemImage: "keyboard")
                    }

                    NavigationLink {
                        RunePadView()
                    } label: {
                        Label("Rune Pad", systemImage: "textformat.alt")
                    }

                    NavigationLink {
                        AlphabetChartView()
                    } label: {
                        Label("Alphabet chart", systemImage: "square.grid.3x3")
                    }
                }

                Section("Keyboard defaults") {
                    LayoutPicker()
                    KeyFacePicker()
                    Toggle("Haptic feedback", isOn: hapticsBinding)
                    Toggle("Latin hints under rune keys", isOn: hintsBinding)
                }

                Section {
                    Text("Unofficial fan project. Not affiliated with, endorsed by, or connected to Sleep Token or their rights holders.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Sleep Token KB")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                RuneFont.registerIfNeeded()
            }
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
        Picker("Layout", selection: $mode) {
            ForEach(LayoutMode.allCases) { m in
                Text(m.title).tag(m)
            }
        }
        .onChange(of: mode) { _, newValue in
            KeyboardPreferences.layoutMode = newValue
        }
        .onAppear { mode = KeyboardPreferences.layoutMode }
    }
}

private struct KeyFacePicker: View {
    @State private var style: KeyFaceStyle = KeyboardPreferences.keyFaceStyle

    var body: some View {
        Picker("Key look", selection: $style) {
            ForEach(KeyFaceStyle.allCases) { s in
                Text(s.title).tag(s)
            }
        }
        .onChange(of: style) { _, newValue in
            KeyboardPreferences.keyFaceStyle = newValue
        }
        .onAppear { style = KeyboardPreferences.keyFaceStyle }
    }
}

#Preview {
    ContentView()
}
