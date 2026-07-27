import SwiftUI

struct AlphabetChartView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Twenty-six glyphs, one per letter. The keyboard and Rune Pad both draw from this set.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkDim)
                    .lineSpacing(3)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(SleepTokenLetter.allCases) { letter in
                        GlyphCard(letter: letter)
                    }
                }
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
            SymbolGlyphView(letter: letter, foreground: Theme.ink)
                .frame(width: 40, height: 40)
                .padding(.top, 6)

            Text(letter.upperLatin)
                .font(Theme.display(20, weight: .bold))
                .foregroundStyle(Theme.gold)

            Text(letter.glyphDescription)
                .font(.caption2)
                .foregroundStyle(Theme.inkDim)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(minHeight: 42, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
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
