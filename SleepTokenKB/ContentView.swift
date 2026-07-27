import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Begin")
                        NavigationLink { EnableKeyboardView() } label: {
                            DestinationCard(
                                glyph: .e,
                                title: "Enable the keyboard",
                                detail: "One-time setup in Settings. Then the runes follow you into every app."
                            )
                        }
                        NavigationLink { RunePadView() } label: {
                            DestinationCard(
                                glyph: .r,
                                title: "Rune Pad",
                                detail: "Compose vertical ritual text, read it back in Latin, export it anywhere."
                            )
                        }
                        NavigationLink { AlphabetChartView() } label: {
                            DestinationCard(
                                glyph: .a,
                                title: "The alphabet",
                                detail: "All twenty-six glyphs with their letters and construction notes."
                            )
                        }
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
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Keyboard defaults")
                        VStack(spacing: 16) {
                            LayoutPicker()
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                            KeyFacePicker()
                            Rectangle().fill(Theme.hairline).frame(height: 1)
                            Toggle(isOn: hapticsBinding) {
                                Text("Haptic feedback")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.ink)
                            }
                            .tint(Theme.goldDeep)
                        }
                        .ritualCard()
                    }

                    footer
                }
                .padding(20)
            }
            .background(RitualBackground())
            // The root deliberately has no navigation title (the hero is the title),
            // which also means no system scroll-edge bar — so scrolled content would
            // collide with the status bar. This scrim fades it out instead.
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Theme.field, Theme.field.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 110)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                RuneFont.registerIfNeeded()
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Unofficial fan keyboard")
                .font(Theme.overline())
                .tracking(2.6)
                .foregroundStyle(Theme.gold)

            Text("Sleep Token KB")
                .font(Theme.display(40, weight: .bold))
                .foregroundStyle(Theme.ink)

            // The app demonstrating its own purpose: the name, spelled in the alphabet.
            RuneWordRow(word: "sleep token", glyphSize: 15)
                .padding(.top, 2)

            Text("Type English everywhere with ritual keycaps. When you want real runes, compose in Rune Pad and carry them out as images.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkDim)
                .lineSpacing(3)
                .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private func waysRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Theme.display(17))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Theme.inkDim)
                .lineSpacing(2)
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            RuneWordRow(word: "worship", glyphSize: 10, spacing: 8, color: Theme.inkFaint)
            Text("Unofficial fan project. Not affiliated with, endorsed by, or connected to Sleep Token or their rights holders.")
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { KeyboardPreferences.hapticsEnabled },
            set: { KeyboardPreferences.hapticsEnabled = $0 }
        )
    }
}

// MARK: - Destination cards

private struct DestinationCard: View {
    let glyph: SleepTokenLetter
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            SymbolGlyphView(letter: glyph, foreground: Theme.gold)
                .frame(width: 22, height: 22)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surfaceHigh)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.gold.opacity(0.22), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.display(17))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkDim)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .ritualCard(padding: 14)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Defaults controls

private struct LayoutPicker: View {
    @State private var mode: LayoutMode = KeyboardPreferences.layoutMode

    var body: some View {
        DefaultsRow(title: "Layout") {
            Picker("Layout", selection: $mode) {
                ForEach(LayoutMode.allCases) { m in
                    Text(m.shortTitle).tag(m)
                }
            }
            .pickerStyle(.segmented)
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
        DefaultsRow(title: "Key look", caption: caption) {
            Picker("Key look", selection: $style) {
                ForEach(KeyFaceStyle.allCases) { s in
                    Text(s.shortTitle).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
        .onChange(of: style) { _, newValue in
            KeyboardPreferences.keyFaceStyle = newValue
        }
        .onAppear { style = KeyboardPreferences.keyFaceStyle }
    }

    private var caption: String {
        switch style {
        case .runeArt: "Pure glyph keycaps. Typing still inserts English."
        case .runeHints: "Glyphs with a small Latin letter beneath — the learning face."
        case .letters: "Plain English keycaps."
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
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
}
