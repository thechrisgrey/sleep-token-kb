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
    @Environment(\.scenePhase) private var scenePhase
    /// The root screen has no navigation title — the hero *is* the title — so it keeps
    /// its 40pt rather than rounding down to `.largeTitle`'s 34, and scales from there.
    @ScaledMetric(relativeTo: .largeTitle) private var heroTitleSize: CGFloat = 40
    @State private var showsEnableCard = EnableThreshold.showsEnableCard(
        enabledKeyboards: UserDefaults.standard.stringArray(forKey: "AppleKeyboards"),
        manuallyHidden: UserDefaults.standard.bool(forKey: EnableThreshold.manuallyHiddenKey)
    )
    @State private var enableGuidePresented = false
    #if DEBUG
    @State private var debugRouteToSettings = false
    @State private var debugForceEnableCard = false
    #endif

    var body: some View {
        NavigationStack {
            // The proxy supplies the real top safe-area inset, so the status-bar
            // scrim is sized per device instead of a flat guess.
            GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero

                    VStack(alignment: .leading, spacing: 10) {
                        if showsEnableCard {
                            Button { enableGuidePresented = true } label: {
                                DestinationCard(
                                    glyph: .e,
                                    title: "Enable the keyboard",
                                    detail: "One-time setup in Settings. Then the runes follow you into every app."
                                )
                            }
                            .buttonStyle(.plain)
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
                        NavigationLink { SettingsView(theme: themeBinding) } label: {
                            DestinationCard(
                                glyph: .s,
                                title: "Settings",
                                detail: "Theme, layout, key faces, haptics."
                            )
                        }
                    }

                    footer
                }
                .padding(20)
                .readableColumn()
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
            // The guide's door stays in the hierarchy even after the card hides:
            // returning from Settings.app flips showsEnableCard while the guide
            // is pushed, and a vanishing NavigationLink would take the pushed
            // screen down with it — ejecting the user mid-setup at the exact
            // moment step IV sends them back here.
            .navigationDestination(isPresented: $enableGuidePresented) {
                EnableKeyboardView()
            }
            #if DEBUG
            .navigationDestination(isPresented: $debugRouteToSettings) {
                SettingsView(theme: themeBinding)
            }
            #endif
            .onAppear {
                RuneFont.registerIfNeeded()
                refreshThreshold()
                #if DEBUG
                applyScreenshotOverrides()
                #endif
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshThreshold() }
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Unofficial fan keyboard")
                .font(Theme.overline())
                .tracking(2.6)
                .foregroundStyle(Theme.gold)

            Text("Ritual Keyboard")
                .font(Theme.display(scaledSize: heroTitleSize, weight: .bold))
                .foregroundStyle(Theme.ink)

            // The app demonstrating its own purpose: the name, spelled in the alphabet.
            // Jerry perches at the end of the wordmark, if you look closely.
            HStack(spacing: 14) {
                RuneWordRow(word: "sleep token", glyphSize: 15)
                HiddenJerry(spot: .heroRow, height: 14)
            }
            .padding(.top, 2)

            Text("English everywhere, runes on the keys — and real runes in Rune Pad.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkDim)
                .lineSpacing(3)
                .padding(.top, 4)
        }
        .padding(.top, 24)
    }

    // MARK: - Enable-card threshold

    private func refreshThreshold() {
        #if DEBUG
        if debugForceEnableCard {
            showsEnableCard = true
            return
        }
        #endif
        showsEnableCard = EnableThreshold.showsEnableCard(
            enabledKeyboards: UserDefaults.standard.stringArray(forKey: "AppleKeyboards"),
            manuallyHidden: UserDefaults.standard.bool(forKey: EnableThreshold.manuallyHiddenKey)
        )
    }

    #if DEBUG
    private func applyScreenshotOverrides() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-force-enable-card") {
            debugForceEnableCard = true
            showsEnableCard = true
        }
        if arguments.contains("-force-arcadia") { store.mode = .evenInArcadia }
        if arguments.contains("-force-ritual") { store.mode = .ritual }
        if arguments.contains("-route-settings") { debugRouteToSettings = true }
    }
    #endif

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
                    .font(Theme.display(.footnote, weight: .regular))
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
                    .font(Theme.display(.body))
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

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
}
