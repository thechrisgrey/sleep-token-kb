import SwiftUI

/// Ritual-minimal design system for the host app.
///
/// The host app commits to one appearance: obsidian field, bone ink, antique-gold
/// accent, serif display type with wide tracking. Dark-only is deliberate — the app is
/// ceremonial surface, not a document editor. The keyboard extension does NOT use this
/// theme: it sits inside other apps and mirrors the system keyboard in both appearances.
enum Theme {

    // MARK: - Palette

    /// The page itself. Near-black with a trace of warmth so pure-black OLED smear
    /// never bands against the cards.
    static let field = Color(red: 0.055, green: 0.051, blue: 0.058)

    /// Raised card surface.
    static let surface = Color(red: 0.094, green: 0.088, blue: 0.098)

    /// Interactive surfaces (pad keys, chips) — one step above `surface`.
    static let surfaceHigh = Color(red: 0.145, green: 0.137, blue: 0.152)

    /// Primary ink: bone, not white. Pure white on near-black glares.
    static let ink = Color(red: 0.92, green: 0.90, blue: 0.85)

    /// Secondary ink for supporting copy.
    static let inkDim = Color(red: 0.62, green: 0.60, blue: 0.56)

    /// Tertiary ink for ornament and legal copy.
    static let inkFaint = Color(red: 0.42, green: 0.41, blue: 0.39)

    /// Antique gold. The only saturated colour in the app; it marks the interactive
    /// and the sacred (caret, step numerals, active states, glyph accents).
    static let gold = Color(red: 0.80, green: 0.67, blue: 0.40)

    /// Gold for large fills where full strength would glow too hard.
    static let goldDeep = Color(red: 0.62, green: 0.50, blue: 0.28)

    /// One-pixel-feeling borders on cards and dividers.
    static let hairline = Color.white.opacity(0.09)

    /// Amber used only by the spell-check flag — warm like the gold, but clearly
    /// a caution rather than an accent.
    static let caution = Color(red: 0.87, green: 0.56, blue: 0.32)

    // MARK: - Type

    /// Display face: the system serif (New York). Distinctive against the glyphs
    /// without bundling a second custom font next to SleepTokenRunes.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Tracked uppercase label, the section voice of the whole app.
    static func overline(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold)
    }
}

// MARK: - Background

/// Obsidian field with a faint gold glow bleeding down from the top — candlelight
/// against stone, not a gradient poster.
struct RitualBackground: View {
    var body: some View {
        ZStack {
            Theme.field
            RadialGradient(
                colors: [Theme.gold.opacity(0.085), .clear],
                center: UnitPoint(x: 0.5, y: -0.15),
                startRadius: 0,
                endRadius: 420
            )
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
            .foregroundStyle(Theme.inkDim)
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

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    /// Raised obsidian card with a hairline border.
    func ritualCard(padding: CGFloat = 16) -> some View {
        modifier(RitualCard(padding: padding))
    }
}
