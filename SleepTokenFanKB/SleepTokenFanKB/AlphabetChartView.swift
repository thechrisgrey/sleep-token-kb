import SwiftUI

struct AlphabetChartView: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(SleepTokenLetter.allCases) { letter in
                    VStack(spacing: 8) {
                        SymbolGlyphView(letter: letter)
                            .frame(width: 48, height: 48)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                            )

                        Text(letter.upperLatin)
                            .font(.title3.weight(.bold).monospaced())

                        Text(letter.glyphDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .frame(minHeight: 36)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Alphabet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AlphabetChartView()
    }
}
