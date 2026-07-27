import SwiftUI

struct AlphabetChartView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Two columns at accessibility sizes so the scaled descriptions keep a
    /// workable measure; three otherwise.
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom, spacing: 10) {
                    Text("Twenty-six glyphs, one per letter. The keyboard and Rune Pad both draw from this set.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkDim)
                        .lineSpacing(3)
                    HiddenJerry(spot: .chartIntro, height: 13)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(SleepTokenLetter.allCases) { letter in
                        GlyphCard(letter: letter)
                    }
                }

                // A twenty-seventh resident of the chart, for those who count.
                HiddenJerry(spot: .chartFoot, height: 14)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .background(RitualBackground())
        .navigationTitle("Alphabet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GlyphCard: View {
    let letter: SleepTokenLetter

    var body: some View {
        VStack(spacing: 10) {
            // Decorative here: the card's own label already carries letter and
            // description, so the glyph's built-in label/hint must not double up.
            SymbolGlyphView(letter: letter, foreground: Theme.ink)
                .frame(width: 40, height: 40)
                .padding(.top, 6)
                .accessibilityHidden(true)

            Text(letter.upperLatin)
                .font(Theme.display(20, weight: .bold))
                .foregroundStyle(Theme.gold)

            // No line limit: the description IS this screen's content, so at large
            // Dynamic Type the row grows rather than the prose truncating. The
            // minHeight keeps rows even at default size.
            Text(letter.glyphDescription)
                .font(.caption2)
                .foregroundStyle(Theme.inkDim)
                .multilineTextAlignment(.center)
                .frame(minHeight: 42, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .ritualCard(padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(letter.upperLatin). \(letter.glyphDescription)")
    }
}

#Preview {
    NavigationStack {
        AlphabetChartView()
    }
    .preferredColorScheme(.dark)
    .tint(Theme.gold)
}
