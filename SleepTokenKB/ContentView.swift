import SwiftUI

struct ContentView: View {
    /// `@State` so the observable store's identity is stable for this view tree;
    /// reads of `Theme` colours inside any body register against it automatically.
    @State private var store = ThemeStore.shared
    @State private var hunt = JerryHunt.shared
    @State private var ceremonyActive = false
    /// Selection the picker shows while the ceremony's curtain is still rising
    /// (the real mode flips only once the curtain is opaque).
    @State private var pendingMode: ThemeMode?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            // The proxy supplies the real top safe-area inset, so the status-bar
            // scrim is sized per device instead of a flat guess.
            GeometryReader { proxy in
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
                        .overlay(alignment: .bottomTrailing) {
                            HiddenJerry(spot: .waysCard, height: 13)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Appearance")
                        DefaultsRow(title: "Theme", caption: themeCaption) {
                            Picker("Theme", selection: themeBinding) {
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
            // collide with the status bar. This scrim fades it out instead, ending
            // just below the status bar on every device class.
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Theme.field, Theme.field.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: proxy.safeAreaInsets.top + 44)
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
        .tint(Theme.gold)
        // While either ceremony's curtain covers the app, the controls beneath
        // must leave the accessibility tree too — invisible but activatable is
        // worse than invisible.
        .accessibilityHidden(ceremonyActive || hunt.celebrationPending)
        .overlay {
            if ceremonyActive {
                ArcadiaRevealView(
                    onCurtainClosed: {
                        store.mode = .evenInArcadia
                        pendingMode = nil
                    },
                    onFinished: { ceremonyActive = false }
                )
            }
        }
        // The tenth Jerry can land on any screen; this overlay sits on the
        // NavigationStack, so it covers pushed children too.
        .overlay {
            if hunt.celebrationPending {
                DamoclesRevealView(onFinished: { hunt.celebrationDidFinish() })
            }
        }
    }

    // MARK: - Theme switching

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { pendingMode ?? store.mode },
            set: { requestTheme($0) }
        )
    }

    private var themeCaption: String {
        switch pendingMode ?? store.mode {
        case .ritual: "Obsidian and gold. The original ceremony."
        case .evenInArcadia: "Pink overgrowth on black stone. The flamingo keeps watch."
        }
    }

    private func requestTheme(_ mode: ThemeMode) {
        guard mode != store.mode, !ceremonyActive else { return }
        if mode == .evenInArcadia && !reduceMotion {
            // The full ceremony: curtain, wordmark, flamingo, dissolve.
            pendingMode = mode
            ceremonyActive = true
        } else {
            withAnimation(.easeInOut(duration: 0.45)) { store.mode = mode }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Unofficial fan keyboard")
                .font(Theme.overline())
                .tracking(2.6)
                .foregroundStyle(Theme.gold)

            Text("Ritual Keyboard")
                .font(Theme.display(40, weight: .bold))
                .foregroundStyle(Theme.ink)

            // The app demonstrating its own purpose: the name, spelled in the alphabet.
            // Jerry perches at the end of the wordmark, if you look closely.
            HStack(spacing: 14) {
                RuneWordRow(word: "sleep token", glyphSize: 15)
                HiddenJerry(spot: .heroRow, height: 14)
            }
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
            // Same slot, theme-appropriate ornament: the flamingo keeps the footer
            // in Arcadia, the rune word keeps it in Ritual.
            if store.mode == .evenInArcadia {
                BlackFlamingo(height: 54)
            } else {
                RuneWordRow(word: "worship", glyphSize: 10, spacing: 8, color: Theme.inkFaint)
            }
            // A dedication is not a legal notice, so it does not share the legal
            // notice's voice: serif rather than system, and set above the rule that
            // separates it from the fine print. Quiet, but deliberately not hidden.
            VStack(spacing: 10) {
                Text("Dedicated to Erikka Rose")
                    .font(Theme.display(13, weight: .regular))
                    .italic()
                    .foregroundStyle(Theme.inkDim)

                Rectangle()
                    .fill(Theme.hairline)
                    .frame(width: 44, height: 1)

                Text("Unofficial fan project. Not affiliated with, endorsed by, or connected to Sleep Token or their rights holders.")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .overlay(alignment: .bottomTrailing) {
            HiddenJerry(spot: .homeFooter, height: 12)
        }
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
                    Text("Needs Full Access, in Settings")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkFaint)
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
