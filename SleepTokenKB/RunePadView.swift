import SwiftUI
import UIKit

/// Vertical ritual writing, read back in Latin, exported in whichever form the
/// destination app understands.
///
/// Layout: plaque canvas (the runes), translation strip (the Latin reading with live
/// spell check), letter pad. Long words / many columns automatically scale down so the
/// canvas stays in view.
struct RunePadView: View {
    /// Words separated by spaces; each word is one vertical column.
    @State private var text = ""
    @State private var status: String?
    @State private var isExporting = false
    @State private var shareItem: ShareItem?

    @Environment(\.displayScale) private var displayScale

    private let preferredRuneSize: CGFloat = 32
    private let rows: [[SleepTokenLetter]] = KeyboardLayout.qwertyRows

    var body: some View {
        VStack(spacing: 14) {
            canvas
            translationStrip
            letterPad

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RitualBackground())
        .navigationTitle("Rune Pad")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { _ = RuneFont.registerIfNeeded() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Clear") { text = ""; status = nil }
                    .disabled(text.isEmpty)

                exportMenu
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            if text.isEmpty {
                emptyState
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                let metrics = CanvasMetrics.fitted(
                    columns: columns,
                    in: geo.size,
                    preferredRuneSize: preferredRuneSize
                )
                VerticalRuneColumnsView(
                    columns: columns,
                    runeSize: metrics.runeSize,
                    columnSpacing: metrics.columnSpacing,
                    runeSpacing: metrics.runeSpacing,
                    ink: Theme.ink,
                    showChrome: true
                )
                .padding(metrics.padding)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .animation(.easeOut(duration: 0.15), value: text)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190, maxHeight: 260)
        .ritualCard(padding: 0)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            RuneWordRow(word: "sleep token", glyphSize: 13, spacing: 9, color: Theme.inkFaint)
            Text("Tap the keys below. Runes stack top to bottom;\nspace starts a new column.")
                .font(.caption)
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    // MARK: - Translation + spell check

    /// Latin reading of each finished column, lowercase for the checker.
    private var latinWords: [String] {
        columns
            .filter { !$0.isEmpty }
            .map { SleepTokenLetter.latinTranslation(of: $0) }
    }

    /// Words the system dictionary does not recognise. Live, per keystroke — the last
    /// column flags until it becomes a word, exactly like spell check anywhere else.
    private var misspelledWords: Set<String> {
        let checker = UITextChecker()
        var flagged: Set<String> = []
        for word in latinWords where word.count > 1 {
            let range = NSRange(location: 0, length: word.utf16.count)
            let miss = checker.rangeOfMisspelledWord(
                in: word, range: range, startingAt: 0, wrap: false, language: "en_US"
            )
            if miss.location != NSNotFound { flagged.insert(word) }
        }
        return flagged
    }

    @ViewBuilder
    private var translationStrip: some View {
        if !latinWords.isEmpty {
            let flagged = misspelledWords
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("READS")
                        .font(Theme.overline(9))
                        .tracking(2.2)
                        .foregroundStyle(Theme.inkDim)
                    translationText(flagged: flagged)
                        .font(Theme.display(16, weight: .medium))
                        .kerning(1.4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !flagged.isEmpty {
                    Text("Underlined words are not in the dictionary.")
                        .font(.caption2)
                        .foregroundStyle(Theme.caution.opacity(0.8))
                }
            }
            .ritualCard(padding: 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reads \(latinWords.joined(separator: " "))")
        }
    }

    private func translationText(flagged: Set<String>) -> Text {
        var combined = Text("")
        for (index, word) in latinWords.enumerated() {
            var piece = Text(word.uppercased())
            if flagged.contains(word) {
                piece = piece
                    .foregroundColor(Theme.caution)
                    .underline(true, color: Theme.caution)
            } else {
                piece = piece.foregroundColor(Theme.ink)
            }
            combined = index == 0 ? piece : combined + Text("  ") + piece
        }
        return combined
    }

    // MARK: - Columns model

    private var columns: [String] {
        if text.isEmpty { return [""] }
        if text.hasSuffix(" ") {
            return String(text.dropLast()).components(separatedBy: " ") + [""]
        }
        return text.components(separatedBy: " ")
    }

    // MARK: - Pad

    private var letterPad: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 5) {
                    ForEach(row) { letter in
                        Button { text.append(letter.exactRuneString) } label: {
                            VStack(spacing: 2) {
                                SymbolGlyphView(letter: letter, foreground: Theme.ink)
                                    .frame(height: 20)
                                    .accessibilityHidden(true)
                                Text(letter.upperLatin)
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.inkFaint)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Theme.surfaceHigh)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(letter.upperLatin)
                    }
                }
                .padding(.horizontal, index == 1 ? 12 : 0)
            }

            HStack(spacing: 8) {
                Button(action: startNewColumn) {
                    Text("SPACE · NEW COLUMN")
                        .font(Theme.overline(10))
                        .tracking(1.8)
                        .foregroundStyle(Theme.inkDim)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Space, starts a new column")

                Button(action: deleteBackward) {
                    Image(systemName: "delete.left")
                        .foregroundStyle(Theme.ink)
                        .frame(width: 56, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete")
            }
        }
        .ritualCard(padding: 10)
    }

    // MARK: - Export

    private var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var exportMenu: some View {
        Menu {
            Section("Copy image") {
                Button {
                    Task { await copyImage(style: .lightInk) }
                } label: {
                    Label("For dark backgrounds", systemImage: "moon")
                }
                Button {
                    Task { await copyImage(style: .darkInk) }
                } label: {
                    Label("For light backgrounds", systemImage: "sun.max")
                }
                Button {
                    Task { await copyImage(style: .plaque) }
                } label: {
                    Label("On plaque", systemImage: "rectangle.fill")
                }
            }
            Button {
                Task { await shareImage() }
            } label: {
                Label("Share as image", systemImage: "square.and.arrow.up")
            }
            Button {
                copyLatinText()
            } label: {
                Label("Copy as Latin text", systemImage: "textformat")
            }
        } label: {
            if isExporting {
                ProgressView()
            } else {
                Label("Export", systemImage: "square.and.arrow.up")
            }
        }
        .disabled(!hasContent || isExporting)
    }

    // MARK: - Actions

    private func startNewColumn() {
        guard !text.isEmpty, !text.hasSuffix(" ") else { return }
        text.append(" ")
    }

    private func deleteBackward() {
        guard !text.isEmpty else { return }
        text.removeLast()
    }

    private func copyLatinText() {
        UIPasteboard.general.string = latinWords.joined(separator: " ")
        status = "Latin text copied. Paste it anywhere to spell check or search."
    }

    @MainActor
    private func copyImage(style: RuneExportStyle) async {
        guard let image = await renderImage(style: style) else {
            status = "Could not render image. Try again."
            return
        }
        if let png = image.pngData() {
            UIPasteboard.general.setItems([[
                "public.png": png,
                "com.apple.uikit.image": image
            ]], options: [:])
            UIPasteboard.general.image = image
        } else {
            UIPasteboard.general.image = image
        }
        status = style.copiedMessage
    }

    @MainActor
    private func shareImage() async {
        guard let image = await renderImage(style: .plaque),
              let png = image.pngData() else {
            status = "Could not render image. Try again."
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sleep-token-runes.png")
        do {
            try png.write(to: url)
            shareItem = ShareItem(url: url)
            status = nil
        } catch {
            status = "Could not prepare the share file. Try again."
        }
    }

    @MainActor
    private func renderImage(style: RuneExportStyle) async -> UIImage? {
        isExporting = true
        defer { isExporting = false }

        _ = RuneFont.registerIfNeeded()

        let exportColumns = columns.filter { !$0.isEmpty }
        // Export at a comfortable resolution (not the on-screen shrunk size).
        let exportMetrics = CanvasMetrics.forExport(
            columns: exportColumns,
            preferredRuneSize: preferredRuneSize
        )

        let runes = VerticalRuneColumnsView(
            columns: exportColumns,
            runeSize: exportMetrics.runeSize,
            columnSpacing: exportMetrics.columnSpacing,
            runeSpacing: exportMetrics.runeSpacing,
            ink: style.ink,
            showChrome: false
        )

        let content = Group {
            switch style {
            case .lightInk, .darkInk:
                runes.padding(24)
            case .plaque:
                runes
                    .padding(36)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(RuneExportStyle.plaqueFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .padding(4)
            }
        }

        let renderer = ImageRenderer(content: content)
        // UIScreen.main is deprecated in iOS 26; displayScale is the SwiftUI-native
        // equivalent and correctly follows the scene this view is actually in.
        renderer.scale = displayScale
        renderer.isOpaque = false

        try? await Task.sleep(nanoseconds: 50_000_000)

        return renderer.uiImage
    }
}

// MARK: - Export styles

/// The three image forms. Two transparent PNGs (one per destination background) and a
/// plaque that is legible on any background because it brings its own.
private enum RuneExportStyle {
    case lightInk
    case darkInk
    case plaque

    static let plaqueFill = Color(red: 0.062, green: 0.058, blue: 0.066)

    var ink: Color {
        switch self {
        case .lightInk: Color(white: 0.93)
        case .darkInk: Color(white: 0.08)
        case .plaque: Theme.ink
        }
    }

    var copiedMessage: String {
        switch self {
        case .lightInk: "Copied: transparent, light ink. Paste over dark backgrounds."
        case .darkInk: "Copied: transparent, dark ink. Paste over light backgrounds."
        case .plaque: "Copied: plaque image. Legible on any background."
        }
    }
}

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Fit metrics

private struct CanvasMetrics: Equatable {
    var runeSize: CGFloat
    var columnSpacing: CGFloat
    var runeSpacing: CGFloat
    var padding: CGFloat

    /// Largest rune size that still fits all columns/rows inside `size`.
    static func fitted(
        columns: [String],
        in size: CGSize,
        preferredRuneSize: CGFloat
    ) -> CanvasMetrics {
        let colCount = max(columns.count, 1)
        // Empty column still needs one cell (caret).
        let maxRows = max(columns.map { max($0.count, 1) }.max() ?? 1, 1)

        let padding: CGFloat = 16
        let availW = max(size.width - padding * 2, 48)
        let availH = max(size.height - padding * 2, 48)

        var lo: CGFloat = 8
        var hi = preferredRuneSize
        var best = lo

        for _ in 0..<24 {
            let mid = (lo + hi) / 2
            if Self.fits(runeSize: mid, colCount: colCount, maxRows: maxRows, availW: availW, availH: availH) {
                best = mid
                lo = mid
            } else {
                hi = mid
            }
        }

        return Self.metrics(runeSize: min(preferredRuneSize, max(8, best)), padding: padding)
    }

    /// Comfortable size for PNG export (scale up long text slightly less).
    static func forExport(columns: [String], preferredRuneSize: CGFloat) -> CanvasMetrics {
        let colCount = max(columns.count, 1)
        let maxRows = max(columns.map(\.count).max() ?? 1, 1)
        // Soft cap so huge messages still export cleanly
        let complexity = CGFloat(colCount * max(maxRows, 1))
        let size: CGFloat
        if complexity <= 24 {
            size = preferredRuneSize
        } else if complexity <= 60 {
            size = 26
        } else if complexity <= 120 {
            size = 20
        } else {
            size = 16
        }
        return metrics(runeSize: size, padding: 24)
    }

    private static func metrics(runeSize: CGFloat, padding: CGFloat) -> CanvasMetrics {
        CanvasMetrics(
            runeSize: runeSize,
            columnSpacing: max(6, runeSize * 0.45),
            runeSpacing: max(3, runeSize * 0.22),
            padding: padding
        )
    }

    private static func fits(
        runeSize: CGFloat,
        colCount: Int,
        maxRows: Int,
        availW: CGFloat,
        availH: CGFloat
    ) -> Bool {
        let cell = runeSize + 10
        let colW = cell + 12
        let colSpacing = max(6, runeSize * 0.45)
        let runeSpacing = max(3, runeSize * 0.22)
        let chromeV: CGFloat = 16

        let width = CGFloat(colCount) * colW + CGFloat(max(colCount - 1, 0)) * colSpacing
        let height = CGFloat(maxRows) * cell
            + CGFloat(max(maxRows - 1, 0)) * runeSpacing
            + chromeV

        return width <= availW && height <= availH
    }
}

// MARK: - Shared column layout (screen + export)

private struct VerticalRuneColumnsView: View {
    let columns: [String]
    let runeSize: CGFloat
    let columnSpacing: CGFloat
    let runeSpacing: CGFloat
    let ink: Color
    let showChrome: Bool

    private var cell: CGFloat { runeSize + 10 }

    var body: some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            if columns.isEmpty {
                Color.clear.frame(width: 1, height: 1)
            } else {
                ForEach(Array(columns.enumerated()), id: \.offset) { columnIndex, word in
                    VStack(spacing: runeSpacing) {
                        if word.isEmpty {
                            if showChrome {
                                caret
                                    .frame(width: cell, height: cell)
                            }
                        } else {
                            ForEach(Array(word.enumerated()), id: \.offset) { _, character in
                                runeCell(for: character)
                            }
                            if showChrome, columnIndex == columns.count - 1 {
                                caret
                                    .frame(width: cell)
                            }
                        }
                    }
                    .frame(width: cell + (showChrome ? 12 : 4))
                    .padding(.vertical, showChrome ? 8 : 2)
                    .background {
                        if showChrome {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func runeCell(for character: Character) -> some View {
        if let letter = SleepTokenLetter.fromRuneCharacter(character) {
            SymbolGlyphView(letter: letter, foreground: ink)
                .frame(width: cell, height: cell)
                .frame(maxWidth: .infinity)
        } else {
            Text(String(character))
                .font(RuneFont.font(size: runeSize))
                .foregroundStyle(ink)
                .frame(width: cell, height: cell, alignment: .center)
                .frame(maxWidth: .infinity)
        }
    }

    private var caret: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.gold.opacity(0.9))
            .frame(width: 2, height: max(8, runeSize * 0.55))
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        RunePadView()
    }
    .preferredColorScheme(.dark)
    .tint(Theme.gold)
}
