import SwiftUI

/// The Settings door: everything the welcome used to dump, in the card language
/// with the tracked-caps section voice — a directory screen is where that
/// scaffolding belongs. The theme binding comes from ContentView, so the Arcadia
/// ceremony still runs on the root overlay above this pushed screen.
struct SettingsView: View {
    @Binding var theme: ThemeMode
    @State private var hunt = JerryHunt.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Appearance")
                    DefaultsRow(title: "Theme", caption: themeCaption) {
                        Picker("Theme", selection: $theme) {
                            ForEach(ThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .ritualCard()
                    .overlay(alignment: .topTrailing) {
                        HiddenJerry(spot: .appearanceCard, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Keyboard defaults")
                    VStack(spacing: 16) {
                        LayoutPicker()
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        KeyFacePicker()
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        HapticsToggle()
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        GlideToggle()
                    }
                    .ritualCard()
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Two ways to write")
                    VStack(alignment: .leading, spacing: 14) {
                        waysRow(
                            title: "System keyboard",
                            detail: "Rune or ABC keycaps — always inserts normal English, so it works in Messages, Notes, everywhere."
                        )
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        waysRow(
                            title: "Rune Pad",
                            detail: "Real vertical runes, exported as images or text for apps that accept pictures."
                        )
                    }
                    .ritualCard()
                    .overlay(alignment: .bottomTrailing) {
                        HiddenJerry(spot: .waysCard, height: 13)
                    }
                }

                if let tally = JerryTally.presentation(found: hunt.found.count,
                                                       total: hunt.totalCount) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "The hunt")
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                // Decorative echo of a found Jerry — not a hiding
                                // spot, not tappable, invisible to VoiceOver.
                                BlackFlamingo(height: 14)
                                    .opacity(0.34)
                                    .accessibilityHidden(true)
                                Text(tally.text)
                                    .font(Theme.display(.body))
                                    .foregroundStyle(Theme.inkDim)
                            }
                            if tally.showsReplay {
                                Button("Play the reward again") {
                                    hunt.celebrationPending = true
                                }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.gold)
                            }
                        }
                        .ritualCard()
                    }
                }

                // Last, because that is where a reader looks for it -- but in the
                // same card and row language as everything above, not shrunk into a
                // footnote. Principle 5 in PRODUCT.md asks for labelling that is part
                // of the design, and a legal-looking block at the bottom of a settings
                // screen is exactly the afterthought it warns about.
                //
                // No HiddenJerry here on purpose: a new spot would raise the hunt's
                // totalCount, and the one card whose job is to be unambiguous is not
                // the place to hide something.
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "About")
                    VStack(alignment: .leading, spacing: 14) {
                        waysRow(
                            title: "What this is",
                            detail: "Fan art. A keyboard and rune composer built by one person, for people who already read the alphabet. The keys wear the runes; the text that arrives is ordinary English."
                        )
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        waysRow(
                            title: "What this is not",
                            detail: "Not affiliated with, endorsed by, sponsored by, or connected to Sleep Token, their label, or their management. No artwork, photography, or audio of theirs is bundled, and the one song reference opens Apple Music rather than playing anything."
                        )
                    }
                    .ritualCard()
                }
            }
            .padding(20)
            .readableColumn()
        }
        .background(RitualBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var themeCaption: String {
        switch theme {
        case .ritual: "Obsidian and gold. The original ceremony."
        case .evenInArcadia: "Pink overgrowth on black stone. The flamingo keeps watch."
        }
    }

    private func waysRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.display(.body))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.inkDim)
                .lineSpacing(2)
        }
    }
}

// MARK: - Defaults controls

/// Owns the seed / write-back / refresh cycle every preference control needs, so the
/// three controls in the defaults card share one sync pattern — including a re-read
/// when the scene becomes active, which keeps the card truthful after the keyboard
/// extension writes the same preferences from its own process.
private struct PreferenceBacked<Value: Equatable, Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    let read: () -> Value
    let write: (Value) -> Void
    @ViewBuilder let content: (Binding<Value>) -> Content
    @State private var value: Value

    init(
        read: @escaping () -> Value,
        write: @escaping (Value) -> Void,
        @ViewBuilder content: @escaping (Binding<Value>) -> Content
    ) {
        self.read = read
        self.write = write
        self.content = content
        _value = State(initialValue: read())
    }

    var body: some View {
        content($value)
            .onChange(of: value) { _, newValue in write(newValue) }
            .onAppear { value = read() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { value = read() }
            }
    }
}

private struct LayoutPicker: View {
    var body: some View {
        PreferenceBacked(
            read: { KeyboardPreferences.layoutMode },
            write: { KeyboardPreferences.layoutMode = $0 }
        ) { $mode in
            DefaultsRow(title: "Layout") {
                Picker("Layout", selection: $mode) {
                    ForEach(LayoutMode.allCases) { m in
                        Text(m.shortTitle)
                            // Segments show the chrome-key short form; VoiceOver
                            // gets the model's full description.
                            .accessibilityLabel(m.accessibilityLabel)
                            .tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct KeyFacePicker: View {
    var body: some View {
        PreferenceBacked(
            read: { KeyboardPreferences.keyFaceStyle },
            write: { KeyboardPreferences.keyFaceStyle = $0 }
        ) { $style in
            DefaultsRow(title: "Key look", caption: Self.caption(for: style)) {
                Picker("Key look", selection: $style) {
                    ForEach(KeyFaceStyle.allCases) { s in
                        Text(s.shortTitle)
                            .accessibilityLabel(s.title)
                            .tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private static func caption(for style: KeyFaceStyle) -> String {
        switch style {
        case .runeArt: "Pure glyph keycaps. Typing still inserts English."
        case .runeHints: "Glyphs with a small Latin letter beneath — the learning face."
        case .letters: "Plain English keycaps."
        }
    }
}

private struct HapticsToggle: View {
    var body: some View {
        PreferenceBacked(
            read: { KeyboardPreferences.hapticsEnabled },
            write: { KeyboardPreferences.hapticsEnabled = $0 }
        ) { $enabled in
            Toggle(isOn: $enabled) {
                // The requirement is stated unconditionally: whether Full Access was
                // granted is a property of the *extension's* process, and the host app
                // cannot read it. Better a permanent caption than a toggle that silently
                // does nothing, which is what shipped before.
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haptic feedback")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Text("Needs Allow Full Access, in Settings")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkDim)
                }
            }
            .tint(Theme.goldDeep)
        }
    }
}

private struct GlideToggle: View {
    var body: some View {
        PreferenceBacked(
            read: { KeyboardPreferences.glideTypingEnabled },
            write: { KeyboardPreferences.glideTypingEnabled = $0 }
        ) { $enabled in
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glide typing")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                    Text("Slide from letter to letter to type a word. QWERTY layout only.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkDim)
                }
            }
            .tint(Theme.goldDeep)
        }
    }
}

/// Label-over-control row used by the defaults card, so both pickers share one shape.
private struct DefaultsRow<Control: View>: View {
    let title: String
    var caption: String? = nil
    @ViewBuilder let control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
            control
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(Theme.inkDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        SettingsView(theme: .constant(.ritual))
    }
    .preferredColorScheme(.dark)
    .tint(Theme.gold)
}
