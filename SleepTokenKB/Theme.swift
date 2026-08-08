import SwiftUI
import Observation

// MARK: - Theme selection

/// The two aesthetics the host app can wear. Strictly UI: switching themes changes
/// colours and ornament only — every screen, control, and behaviour stays identical.
enum ThemeMode: String, CaseIterable, Identifiable {
    /// Obsidian and antique gold — the original ceremony.
    case ritual
    /// Pink overgrowth on black stone, deep arcadian-green flag panels, champagne
    /// ink, and the black flamingo.
    ///
    /// The case name is load-bearing and deliberately unchanged: `rawValue` is what
    /// `ThemeStore` writes to `appThemeMode`, and an unrecognised stored value falls
    /// back to `.ritual`. Renaming it would silently reset the theme for everyone who
    /// had already chosen this one.
    case evenInArcadia

    var id: String { rawValue }

    /// What the picker shows. Shortened to initials so the album title is not a
    /// user-visible label; see docs/RELEASE.md on Guideline 5.2.
    var title: String {
        switch self {
        case .ritual: "Ritual"
        case .evenInArcadia: "EIA"
        }
    }
}

/// Source of truth for the active theme. `@Observable`, so any view that reads a
/// `Theme` colour during body evaluation re-renders when the mode changes.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()
    static let storageKey = "appThemeMode"

    /// Where this store persists. `ObservationIgnored` — it never changes and must
    /// not participate in view invalidation.
    @ObservationIgnored private let defaults: UserDefaults

    var mode: ThemeMode {
        didSet { defaults.set(mode.rawValue, forKey: Self.storageKey) }
    }

    /// Internal (not private) so tests can construct a store over a seeded suite
    /// and exercise the real fallback path; the app itself only ever uses `shared`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        mode = ThemeMode(rawValue: raw) ?? .ritual
    }
}

// MARK: - Palette

/// Design system for the host app. Every property resolves against the active
/// `ThemeStore` mode, so existing call sites (`Theme.ink`, `Theme.gold`, …) retheme
/// without changing. The keyboard extension does NOT use this: it sits inside other
/// apps and mirrors the system keyboard in both appearances.
///
/// `gold` keeps its name as the *accent* role — in Even in Arcadia the accent is
/// dusty pink. "The pinks are very important."
enum Theme {
    private static var mode: ThemeMode { ThemeStore.shared.mode }

    // MARK: Fixed Arcadia constants
    //
    // Named once, referenced everywhere — including by the reveal ceremony, whose
    // palette must stay stable while the theme flips underneath it. Fixed (not
    // mode-resolved) by design.

    /// The era's dusty rose.
    static let arcadiaRose = Color(red: 0.87, green: 0.58, blue: 0.67)

    /// The flag's champagne gilt.
    static let arcadiaChampagne = Color(red: 0.78, green: 0.71, blue: 0.48)

    /// The page itself. Ritual: near-black with a trace of warmth. Arcadia: black
    /// stone with a breath of green.
    static var field: Color {
        switch mode {
        case .ritual: Color(red: 0.055, green: 0.051, blue: 0.058)
        case .evenInArcadia: Color(red: 0.039, green: 0.055, blue: 0.047)
        }
    }

    /// Raised card surface. Arcadia's cards are the merch flag: deep arcadian green.
    static var surface: Color {
        switch mode {
        case .ritual: Color(red: 0.094, green: 0.088, blue: 0.098)
        case .evenInArcadia: Color(red: 0.075, green: 0.114, blue: 0.090)
        }
    }

    /// Interactive surfaces (pad keys, chips) — one step above `surface`.
    static var surfaceHigh: Color {
        switch mode {
        case .ritual: Color(red: 0.145, green: 0.137, blue: 0.152)
        case .evenInArcadia: Color(red: 0.110, green: 0.165, blue: 0.132)
        }
    }

    /// Primary ink. Ritual: bone. Arcadia: champagne — the flag's gilt thread.
    static var ink: Color {
        switch mode {
        case .ritual: Color(red: 0.92, green: 0.90, blue: 0.85)
        case .evenInArcadia: Color(red: 0.93, green: 0.90, blue: 0.82)
        }
    }

    /// Secondary ink for supporting copy.
    static var inkDim: Color {
        switch mode {
        case .ritual: Color(red: 0.62, green: 0.60, blue: 0.56)
        case .evenInArcadia: Color(red: 0.64, green: 0.65, blue: 0.58)
        }
    }

    /// Tertiary ink for ornament and legal copy. Arcadia's carries a faint rose
    /// cast, so the pink reaches the quiet corners (pad hints, chevrons, legal
    /// copy) without shouting.
    ///
    /// Lightness is set by the AA floor, not by taste: this role carries the
    /// unaffiliated notice and Rune Pad's empty state, and at its previous value it
    /// measured 2.8:1 against `surfaceHigh`. Both themes keep their original channel
    /// ratios exactly — only the level moved — so the neutral-warm and rose casts are
    /// unchanged. `ThemeContrastTests` pins the result.
    static var inkFaint: Color {
        switch mode {
        case .ritual: Color(red: 0.561, green: 0.547, blue: 0.521)
        case .evenInArcadia: Color(red: 0.627, green: 0.538, blue: 0.576)
        }
    }

    /// The accent. Ritual: antique gold. Arcadia: dusty rose — pink on black.
    static var gold: Color {
        switch mode {
        case .ritual: Color(red: 0.80, green: 0.67, blue: 0.40)
        case .evenInArcadia: arcadiaRose
        }
    }

    /// Accent for large fills where full strength would glow too hard.
    static var goldDeep: Color {
        switch mode {
        case .ritual: Color(red: 0.62, green: 0.50, blue: 0.28)
        case .evenInArcadia: Color(red: 0.66, green: 0.36, blue: 0.46)
        }
    }

    /// Champagne gold. In Arcadia this is reserved for the sacred — the wordmark and
    /// sigil moments — while pink carries the interactive accent. In Ritual it is
    /// simply the accent again, so shared components can use it freely.
    static var champagne: Color {
        switch mode {
        case .ritual: Color(red: 0.80, green: 0.67, blue: 0.40)
        case .evenInArcadia: arcadiaChampagne
        }
    }

    /// Rune Pad canvas plaque. In Arcadia it is mildly translucent so the petals
    /// drifting down the background stay visible behind the runes.
    static var canvasSurface: Color {
        switch mode {
        case .ritual: surface
        case .evenInArcadia: surface.opacity(0.55)
        }
    }

    /// Section-label ink. Arcadia keeps a sage-green voice here so the green of the
    /// flag stays present between the pinks.
    static var sectionInk: Color {
        switch mode {
        case .ritual: inkDim
        case .evenInArcadia: Color(red: 0.53, green: 0.63, blue: 0.55)
        }
    }

    /// One-pixel-feeling borders on cards and dividers.
    static var hairline: Color {
        switch mode {
        case .ritual: Color.white.opacity(0.09)
        case .evenInArcadia: arcadiaRose.opacity(0.16)
        }
    }

    /// Amber used only by the spell-check flag. Unchanged in Arcadia: the accent
    /// there is pink, so caution must stay a clearly different temperature.
    static var caution: Color {
        Color(red: 0.87, green: 0.56, blue: 0.32)
    }

    // MARK: Type

    /// Display face: the system serif (New York). Distinctive against the glyphs
    /// without bundling a second custom font next to SleepTokenRunes.
    ///
    /// Takes a text *style* rather than a point size, because `.system(size:)` does
    /// not participate in Dynamic Type. The whole serif layer used to be frozen while
    /// the captions beside it scaled, so at accessibility sizes the alphabet chart's
    /// description grew past the letter it was describing — the hierarchy inverted on
    /// the one screen whose job is teaching the alphabet. The keyboard extension had
    /// this right all along (`@ScaledMetric` in `KeyboardRootView`); the host app did
    /// not.
    static func display(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    /// Serif at an explicit point size, for the two display moments whose size does not
    /// land on a text style (the 40pt hero, the 38pt Damocles title) and which would
    /// visibly shrink if rounded down to `.largeTitle`.
    ///
    /// Only for callers that have already scaled the value with `@ScaledMetric` — the
    /// same arrangement the keyboard extension uses for its keycaps. A raw literal
    /// passed here does not scale, which is the bug this API exists to avoid.
    static func display(scaledSize: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaledSize, weight: weight, design: .serif)
    }

    /// Tracked uppercase label, the section voice of the whole app. Defaults to the
    /// smallest style that still clears the platform's 11pt floor — the previous
    /// 9pt and 10pt callers were below it.
    static func overline(_ style: Font.TextStyle = .caption2) -> Font {
        .system(style, weight: .semibold)
    }

    // MARK: Measure

    /// Cap for a single column of body copy on a regular-width screen. The app ships
    /// to iPad, where an uncapped column ran card prose to the full window width —
    /// far past a readable measure at body size.
    static let readableWidth: CGFloat = 620

    /// Width cap for the current horizontal size class, or nil where the layout should
    /// use every point it is given. Driven by size class rather than a device check,
    /// so iPad Split View and Slide Over — which hand a tablet a phone-width window —
    /// get the phone answer without a special case.
    static func contentWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat? {
        sizeClass == .regular ? readableWidth : nil
    }
}

// MARK: - Measure

/// Caps and centres a screen's content column on regular-width screens, leaving
/// compact widths exactly as they were.
private struct ReadableColumn: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            // Inner frame caps the measure; outer frame re-expands so the capped
            // column centres itself instead of hugging the leading edge.
            .frame(maxWidth: Theme.contentWidth(for: sizeClass) ?? .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Constrain this content to a readable measure on iPad and other regular widths.
    func readableColumn() -> some View {
        modifier(ReadableColumn())
    }
}

// MARK: - Background

/// Ritual: obsidian with a faint gold glow from above — candlelight against stone.
/// Arcadia: black-green stone, a dusty-pink bloom of light, and petals adrift.
struct RitualBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.field
            RadialGradient(
                colors: [Theme.gold.opacity(0.085), .clear],
                center: UnitPoint(x: 0.5, y: -0.15),
                startRadius: 0,
                endRadius: 420
            )
            if ThemeStore.shared.mode == .evenInArcadia {
                // A second, lower bloom — the overgrowth creeping up the stone.
                RadialGradient(
                    colors: [Theme.goldDeep.opacity(0.07), .clear],
                    center: UnitPoint(x: 0.15, y: 1.1),
                    startRadius: 0,
                    endRadius: 380
                )
                PetalField(
                    petalCount: 17,
                    maxOpacity: 0.20,
                    speed: reduceMotion ? 0 : 0.012
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Building blocks

/// Tracked uppercase section label ("THE ALPHABET", "DEFAULTS").
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.overline())
            .tracking(2.6)
            .foregroundStyle(Theme.sectionInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A word spelled in rune glyphs — the app's ornament and its own demonstration.
struct RuneWordRow: View {
    let word: String
    var glyphSize: CGFloat = 16
    var spacing: CGFloat = 10
    var color: Color = Theme.gold

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(word.lowercased().enumerated()), id: \.offset) { _, character in
                if let letter = SleepTokenLetter(rawValue: String(character)) {
                    SymbolGlyphView(letter: letter, foreground: color)
                        .frame(width: glyphSize, height: glyphSize)
                } else {
                    // Word gap: a centred interpunct keeps the row's rhythm.
                    Circle()
                        .fill(color.opacity(0.5))
                        .frame(width: 3, height: 3)
                }
            }
        }
        .accessibilityLabel(word)
    }
}

private struct RitualCard: ViewModifier {
    var padding: CGFloat
    /// Overrides the card fill; nil means the standard opaque surface.
    var fill: Color?

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fill ?? Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    /// Raised card with a hairline border, in whichever stone the theme is cut from.
    /// Pass `fill` to override the plaque (e.g. the translucent Rune Pad canvas).
    func ritualCard(padding: CGFloat = 16, fill: Color? = nil) -> some View {
        modifier(RitualCard(padding: padding, fill: fill))
    }
}

// MARK: - Arcadia ornaments

/// A single blossom petal: pointed base, round tip, slightly asymmetric so a field
/// of them never tiles.
struct PetalShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY),
            control: CGPoint(x: rect.minX + w * 1.08, y: rect.minY + h * 0.42)
        )
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + w * 0.5, y: rect.maxY),
            control: CGPoint(x: rect.minX - w * 0.02, y: rect.minY + h * 0.55)
        )
        return p
    }
}

/// Drifting pink petals, deterministic per index so layout never jitters between
/// renders. `speed` 0 renders a static scatter (Reduce Motion, previews).
struct PetalField: View {
    /// Everything about one petal that never changes between frames — seeds,
    /// size, colour, and the base path in local coordinates — computed once at
    /// view construction rather than 24 times a second inside the Canvas loop.
    private struct Petal {
        let seedX: Double
        let seedY: Double
        let width: CGFloat
        let height: CGFloat
        let swayAmplitude: Double
        let swaySpeed: Double
        let rotationSpeed: Double
        let color: Color
        let path: Path
    }

    var petalCount: Int
    var maxOpacity: Double
    /// Screen-heights per second of fall. Ambient use is ~0.012; the reveal ceremony
    /// uses much higher values.
    var speed: Double

    private let petals: [Petal]

    init(petalCount: Int, maxOpacity: Double, speed: Double) {
        self.petalCount = petalCount
        self.maxOpacity = maxOpacity
        self.speed = speed
        self.petals = (0..<petalCount).map { index in
            let seedX = Self.hash01(index, 1)
            let seedY = Self.hash01(index, 2)
            let seedSize = Self.hash01(index, 3)
            let seedHue = Self.hash01(index, 4)
            let seedSway = Self.hash01(index, 5)

            let petalW = 7 + seedSize * 9
            let petalH = petalW * 1.5

            return Petal(
                seedX: seedX,
                seedY: seedY,
                width: petalW,
                height: petalH,
                swayAmplitude: 14 + seedSway * 18,
                swaySpeed: 0.4 + seedSway * 0.5,
                rotationSpeed: 0.25 + seedSway * 0.4,
                // Dusty rose to pale blush, matching the overgrowth.
                color: Color(
                    red: 0.72 + seedHue * 0.2,
                    green: 0.42 + seedHue * 0.24,
                    blue: 0.52 + seedHue * 0.2
                ).opacity(maxOpacity * (0.45 + seedSize * 0.55)),
                path: PetalShape().path(
                    in: CGRect(x: -petalW / 2, y: -petalH / 2, width: petalW, height: petalH)
                )
            )
        }
    }

    /// Deterministic hash in 0..<1 — petals must not use real randomness, or every
    /// body evaluation would reshuffle the sky.
    static func hash01(_ index: Int, _ salt: Double) -> Double {
        let x = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
        return x - floor(x)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: speed == 0)) { timeline in
            let t = speed == 0 ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for petal in petals {
                    // Only the motion is per-frame; everything else is cached.
                    let fall = (petal.seedY + t * speed).truncatingRemainder(dividingBy: 1.15)
                    let y = fall * (size.height + petal.height * 2) - petal.height
                    let sway = sin(t * petal.swaySpeed + petal.seedX * 6.28) * petal.swayAmplitude
                    let x = petal.seedX * size.width + sway
                    let rotation = t * petal.rotationSpeed + petal.seedX * 6.28

                    // GraphicsContext is a value type: the copy scopes the
                    // transform to this petal without a save/restore pair.
                    var petalContext = context
                    petalContext.translateBy(x: x, y: y)
                    petalContext.rotate(by: .radians(rotation))
                    petalContext.fill(petal.path, with: .color(petal.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Jerry, the black flamingo — drawn as an original silhouette (no album art is
/// embedded). Black body, white beak, pink legs: the era's mascot, anatomically
/// as the fans know him.
struct BlackFlamingo: View {
    var height: CGFloat = 60

    var body: some View {
        Canvas { context, size in
            // Design space 100x150, scaled to fit.
            let scale = min(size.width / 100, size.height / 150)
            context.translateBy(
                x: (size.width - 100 * scale) / 2,
                y: (size.height - 150 * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)

            let body = Color(red: 0.075, green: 0.078, blue: 0.088)
            let rose = Color(red: 0.76, green: 0.31, blue: 0.38)
            let bone = Color(red: 0.92, green: 0.89, blue: 0.82)

            // Legs first, so the body overlaps their tops.
            var legs = Path()
            legs.move(to: CGPoint(x: 52, y: 84))
            legs.addLine(to: CGPoint(x: 50, y: 138))
            legs.move(to: CGPoint(x: 50, y: 138))
            legs.addLine(to: CGPoint(x: 59, y: 141))
            // The tucked leg, folded up at the knee.
            legs.move(to: CGPoint(x: 61, y: 84))
            legs.addLine(to: CGPoint(x: 65, y: 101))
            legs.addLine(to: CGPoint(x: 55, y: 108))
            context.stroke(
                legs, with: .color(rose),
                style: StrokeStyle(lineWidth: 2.3, lineCap: .round, lineJoin: .round)
            )

            // Body: a soft teardrop with the tail sweeping up-left.
            var bodyPath = Path()
            bodyPath.move(to: CGPoint(x: 30, y: 62))
            bodyPath.addQuadCurve(to: CGPoint(x: 56, y: 48), control: CGPoint(x: 36, y: 46))
            bodyPath.addQuadCurve(to: CGPoint(x: 80, y: 66), control: CGPoint(x: 74, y: 48))
            bodyPath.addQuadCurve(to: CGPoint(x: 52, y: 88), control: CGPoint(x: 78, y: 88))
            bodyPath.addQuadCurve(to: CGPoint(x: 30, y: 62), control: CGPoint(x: 32, y: 82))
            context.fill(bodyPath, with: .color(body))

            // Neck: the S-curve up from the breast.
            var neck = Path()
            neck.move(to: CGPoint(x: 74, y: 62))
            neck.addQuadCurve(to: CGPoint(x: 82, y: 34), control: CGPoint(x: 90, y: 52))
            neck.addQuadCurve(to: CGPoint(x: 64, y: 18), control: CGPoint(x: 76, y: 16))
            context.stroke(
                neck, with: .color(body),
                style: StrokeStyle(lineWidth: 7, lineCap: .round)
            )

            // Head, and Jerry's white downturned bill.
            context.fill(
                Path(ellipseIn: CGRect(x: 57, y: 11, width: 13, height: 13)),
                with: .color(body)
            )
            var bill = Path()
            bill.move(to: CGPoint(x: 65, y: 16))
            bill.addQuadCurve(to: CGPoint(x: 71, y: 30), control: CGPoint(x: 74, y: 18))
            context.stroke(
                bill, with: .color(bone),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
        }
        .frame(width: height * 100 / 150, height: height)
        .accessibilityLabel("Black flamingo")
    }
}
