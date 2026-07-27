import SwiftUI
import Observation
import UIKit

/// The Jerry hunt: ten black flamingos hidden through the host app. Find them all
/// and the app plays its tribute — "Damocles", opened on Apple Music (the song is
/// linked, never bundled; the audio is not ours to ship).

/// Every hiding place, one case each. Raw values are the persistence format —
/// renaming one resets that Jerry for every fan mid-hunt.
enum JerrySpot: String, CaseIterable {
    case heroRow          // home: perched at the end of the rune wordmark
    case waysCard         // home: corner of the "Two ways to write" card
    case appearanceCard   // home: corner of the Appearance card
    case homeFooter       // home: beside the footer ornament
    case setupCard        // enable guide: corner of the Setup card
    case troubleshooting  // enable guide: corner of the Troubleshooting card
    case chartIntro       // alphabet: end of the intro paragraph
    case chartFoot        // alphabet: below the last row of glyph cards
    case runeCanvas       // rune pad: corner of the canvas plaque
    case runeToolbar      // rune pad: tucked into the navigation bar
}

/// Progress store. `@Observable`, so every hidden Jerry re-renders as the count
/// climbs; persisted, so the hunt survives relaunch.
@Observable
final class JerryHunt {
    static let shared = JerryHunt()
    static let foundKey = "jerrySpotsFound"
    static let celebratedKey = "jerryHuntCelebrated"

    /// "Damocles" — Even in Arcadia (2025). A universal link: the Music app claims
    /// it on devices that have it, the web player answers everywhere else.
    static let damoclesURL = URL(string: "https://music.apple.com/us/song/damocles/1800533715")!

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var found: Set<JerrySpot>
    private(set) var hasCelebrated: Bool
    /// Set exactly once, when the tenth Jerry lands; the root view presents the
    /// ceremony and calls `celebrationDidFinish`.
    var celebrationPending = false

    var totalCount: Int { JerrySpot.allCases.count }
    var isComplete: Bool { found.count == totalCount }

    /// Internal (not private) so tests can run a hunt over their own suite;
    /// the app itself only ever uses `shared`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.stringArray(forKey: Self.foundKey) ?? []
        found = Set(raw.compactMap(JerrySpot.init(rawValue:)))
        hasCelebrated = defaults.bool(forKey: Self.celebratedKey)
    }

    func find(_ spot: JerrySpot) {
        guard !found.contains(spot) else { return }
        found.insert(spot)
        defaults.set(found.map(\.rawValue).sorted(), forKey: Self.foundKey)
        if isComplete && !hasCelebrated {
            celebrationPending = true
        }
    }

    func celebrationDidFinish() {
        celebrationPending = false
        hasCelebrated = true
        defaults.set(true, forKey: Self.celebratedKey)
    }
}

// MARK: - The hidden bird

/// One hidden Jerry. Nearly invisible until found; found ones stay faintly lit so
/// fans can tell which they already have. The tap target is comfortably larger
/// than the bird.
struct HiddenJerry: View {
    let spot: JerrySpot
    var height: CGFloat = 15

    @State private var hunt = JerryHunt.shared
    @State private var pop = false
    @State private var showCount = false

    private var isFound: Bool { hunt.found.contains(spot) }

    var body: some View {
        Button(action: reveal) {
            BlackFlamingo(height: height)
                .opacity(isFound ? 0.34 : 0.13)
                .shadow(
                    color: Theme.arcadiaRose.opacity(isFound ? 0.45 : 0),
                    radius: pop ? 8 : 3
                )
                .scaleEffect(pop ? 1.3 : 1)
                .frame(minWidth: 32, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if showCount {
                Text("\(hunt.found.count) of \(hunt.totalCount)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.arcadiaRose)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.field.opacity(0.92)))
                    .fixedSize()
                    .offset(y: -24)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("Jerry")
        .accessibilityHint(isFound ? "Found." : "A hidden flamingo. Find all ten.")
        .accessibilityValue(isFound ? "found" : "")
    }

    private func reveal() {
        guard !isFound else { return }
        hunt.find(spot)
        AccessibilityNotification.Announcement(
            "Jerry found. \(hunt.found.count) of \(hunt.totalCount)."
        ).post()
        withAnimation(.spring(duration: 0.35)) {
            pop = true
            showCount = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeOut(duration: 0.4)) { pop = false }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.5)) { showCount = false }
        }
    }
}

// MARK: - The reward

/// Played once, when the tenth Jerry is found: black curtain, a storm of petals,
/// Jerry at full height, and DAMOCLES in champagne serif — then the song opens on
/// Apple Music and the curtain dissolves.
struct DamoclesRevealView: View {
    let onFinished: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var curtain = 0.0
    @State private var jerryVisible = false
    @State private var titleVisible = false
    @State private var titleKerning: CGFloat = 14
    @State private var subtitleVisible = false
    @State private var hasOpenedSong = false

    /// Fixed constants, matching the Arcadia ceremony's stable palette.
    private let champagne = Theme.arcadiaChampagne
    private let rose = Theme.arcadiaRose

    var body: some View {
        ZStack {
            Color(red: 0.016, green: 0.024, blue: 0.020)

            RadialGradient(
                colors: [rose.opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.42),
                startRadius: 0,
                endRadius: 320
            )

            PetalField(petalCount: 34, maxOpacity: 0.85, speed: reduceMotion ? 0 : 0.11)

            VStack(spacing: 20) {
                Text("ALL TEN JERRYS FOUND")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(5)
                    .foregroundStyle(rose)
                    .offset(x: 2.5)
                    .opacity(subtitleVisible ? 1 : 0)

                BlackFlamingo(height: 120)
                    .shadow(color: rose.opacity(0.5), radius: 24)
                    .opacity(jerryVisible ? 1 : 0)
                    .scaleEffect(jerryVisible ? 1 : 0.92)

                Text("DAMOCLES")
                    .font(.system(size: 38, weight: .semibold, design: .serif))
                    .kerning(titleKerning)
                    .foregroundStyle(champagne)
                    .shadow(color: champagne.opacity(0.45), radius: 14)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(x: titleKerning / 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text("SLEEP TOKEN · EVEN IN ARCADIA")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3.4)
                    .foregroundStyle(Theme.inkDim)
                    .offset(x: 1.7)
                    .opacity(subtitleVisible ? 1 : 0)
            }
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
        .opacity(curtain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("All ten Jerrys found. Opening Damocles by Sleep Token.")
        .task { await play() }
    }

    /// Sleeps, reporting whether the timeline may continue (false = cancelled).
    private func proceed(after seconds: Double) async -> Bool {
        do {
            try await Task.sleep(for: .seconds(seconds))
            return true
        } catch {
            return false
        }
    }

    /// The song is the reward — it must open even if the ceremony is torn down.
    private func openSongOnce() {
        guard !hasOpenedSong else { return }
        hasOpenedSong = true
        openURL(JerryHunt.damoclesURL)
    }

    private func finishEarly() {
        openSongOnce()
        onFinished()
    }

    @MainActor
    private func play() async {
        AccessibilityNotification.Announcement(
            "All ten Jerrys found. Opening Damocles by Sleep Token."
        ).post()

        withAnimation(.easeIn(duration: 0.3)) { curtain = 1 }
        guard await proceed(after: 0.4) else { finishEarly(); return }

        withAnimation(.easeOut(duration: 0.7)) { jerryVisible = true }
        guard await proceed(after: 0.35) else { finishEarly(); return }
        withAnimation(.easeOut(duration: 1.0)) {
            titleVisible = true
            titleKerning = 6
        }
        guard await proceed(after: 0.5) else { finishEarly(); return }
        withAnimation(.easeOut(duration: 0.5)) { subtitleVisible = true }

        // Hold the tableau, then hand over to the Music app.
        guard await proceed(after: reduceMotion ? 1.0 : 1.7) else { finishEarly(); return }
        openSongOnce()

        guard await proceed(after: 0.5) else { onFinished(); return }
        withAnimation(.easeInOut(duration: 0.7)) { curtain = 0 }
        guard await proceed(after: 0.75) else { onFinished(); return }
        onFinished()
    }
}

#Preview {
    ZStack {
        Color.gray
        DamoclesRevealView(onFinished: {})
    }
}
