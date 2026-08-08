import SwiftUI

/// The ceremony played when the user chooses the EIA theme.
///
/// A black curtain rises, petals begin to fall, the SLEEP TOKEN wordmark breathes in
/// out of the dark in champagne serif, the black flamingo takes its place beneath —
/// then everything dissolves into the re-themed app. The actual theme flip happens
/// behind the opaque curtain (`onCurtainClosed`), so the recolour is never seen raw.
///
/// Reduce Motion never reaches this view: the caller falls back to a plain crossfade.
struct ArcadiaRevealView: View {
    /// Fired once the curtain is fully opaque — the caller flips the theme here.
    let onCurtainClosed: () -> Void
    /// Fired when the ceremony has fully dissolved — the caller removes this view.
    let onFinished: () -> Void

    @State private var curtain = 0.0
    @State private var wordmarkVisible = false
    @State private var wordmarkKerning: CGFloat = 14
    @State private var wordmarkBlur: CGFloat = 7
    @State private var subtitleVisible = false
    @State private var flamingoVisible = false
    @State private var hasClosedCurtain = false

    /// Fixed constants, not mode-resolved `Theme` reads — the ceremony's palette
    /// must not depend on which theme is active while it plays.
    private let champagne = Theme.arcadiaChampagne
    private let rose = Theme.arcadiaRose

    var body: some View {
        ZStack {
            Color(red: 0.016, green: 0.024, blue: 0.020)

            // A faint bloom of pink light behind the wordmark.
            RadialGradient(
                colors: [rose.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0.38),
                startRadius: 0,
                endRadius: 300
            )

            PetalField(petalCount: 26, maxOpacity: 0.8, speed: 0.09)

            VStack(spacing: 18) {
                Text("SLEEP TOKEN")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    .kerning(wordmarkKerning)
                    .foregroundStyle(champagne)
                    .shadow(color: champagne.opacity(0.45), radius: 14)
                    .blur(radius: wordmarkBlur)
                    .opacity(wordmarkVisible ? 1 : 0)
                    // Kerning trails the last glyph; offset by half to keep centred.
                    .offset(x: wordmarkKerning / 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                HStack(spacing: 12) {
                    ornamentLine
                    Text("EVEN IN ARCADIA")
                        .font(.system(.footnote, weight: .semibold))
                        .tracking(6)
                        .foregroundStyle(rose)
                        .offset(x: 3)
                        .fixedSize()
                    ornamentLine
                }
                .opacity(subtitleVisible ? 1 : 0)

                BlackFlamingo(height: 84)
                    .padding(.top, 26)
                    .opacity(flamingoVisible ? 1 : 0)
                    .scaleEffect(flamingoVisible ? 1 : 0.95)
                    // The silhouette is near-black on black; a rim of rose light
                    // keeps it legible without breaking the silhouette.
                    .shadow(color: rose.opacity(0.35), radius: 18)
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
        .opacity(curtain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Switching to the EIA theme")
        .task { await play() }
    }

    private var ornamentLine: some View {
        Rectangle()
            .fill(rose.opacity(0.4))
            .frame(width: 34, height: 1)
    }

    /// Sleeps, reporting whether the timeline may continue. `false` means the task
    /// was cancelled (view torn down mid-ceremony) — callers must commit terminal
    /// state and stop, never fast-forward the choreography.
    private func proceed(after seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }

    /// Cancellation path: the user's choice must never be dropped, so close the
    /// curtain's contract (flip the theme) if that had not happened yet, then end.
    private func finishEarly() {
        if !hasClosedCurtain {
            hasClosedCurtain = true
            onCurtainClosed()
        }
        onFinished()
    }

    @MainActor
    private func play() async {
        AccessibilityNotification.Announcement("Switching to the EIA theme").post()

        // Curtain up: cover the app before the theme flips.
        withAnimation(.easeIn(duration: 0.30)) { curtain = 1 }
        guard await proceed(after: 0.34) else { finishEarly(); return }
        hasClosedCurtain = true
        onCurtainClosed()

        // The wordmark breathes in: letterspacing settles, blur burns off.
        withAnimation(.easeOut(duration: 1.05)) {
            wordmarkVisible = true
            wordmarkKerning = 5
            wordmarkBlur = 0
        }
        guard await proceed(after: 0.55) else { finishEarly(); return }
        withAnimation(.easeOut(duration: 0.5)) { subtitleVisible = true }
        guard await proceed(after: 0.4) else { finishEarly(); return }
        withAnimation(.easeOut(duration: 0.6)) { flamingoVisible = true }

        // Hold the tableau, then dissolve into the re-themed app.
        guard await proceed(after: 1.35) else { finishEarly(); return }
        withAnimation(.easeInOut(duration: 0.85)) { curtain = 0 }
        guard await proceed(after: 0.9) else { finishEarly(); return }
        onFinished()
    }
}

#Preview {
    ZStack {
        Color.gray
        ArcadiaRevealView(onCurtainClosed: {}, onFinished: {})
    }
}
