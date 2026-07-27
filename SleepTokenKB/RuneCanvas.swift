import SwiftUI

/// Geometry and rendering for the Rune Pad canvas, shared by the on-screen plaque
/// and the PNG export paths.
///
/// `CanvasMetrics` is the single source of truth for every derived constant (cell,
/// column width, chrome padding, caret height). `VerticalRuneColumnsView` consumes
/// the same statics, so the fit math and the rendered layout cannot drift — the
/// drift channel that once let the fit ignore the trailing caret entirely.
///
/// Internal (not private) so `SleepTokenKBTests` can pin the arithmetic, following
/// the `KeyboardMetrics` precedent.

// MARK: - Fit metrics

struct CanvasMetrics: Equatable {
    var runeSize: CGFloat
    var columnSpacing: CGFloat
    var runeSpacing: CGFloat
    var padding: CGFloat

    // MARK: Single-source derived geometry

    /// Square cell around one rune.
    static func cell(runeSize: CGFloat) -> CGFloat { runeSize + 10 }

    /// Height of the blinking caret appended after the last rune on screen.
    static func caretHeight(runeSize: CGFloat) -> CGFloat { max(8, runeSize * 0.55) }

    /// Full column width including its chrome outline inset.
    static func columnWidth(cell: CGFloat, showChrome: Bool) -> CGFloat {
        cell + (showChrome ? 12 : 4)
    }

    /// Vertical padding inside one column.
    static func columnVerticalPadding(showChrome: Bool) -> CGFloat {
        showChrome ? 8 : 2
    }

    var cell: CGFloat { Self.cell(runeSize: runeSize) }
    var caretHeight: CGFloat { Self.caretHeight(runeSize: runeSize) }

    /// Height one on-screen column occupies, including the trailing caret the last
    /// column renders (`includeCaret`) and the column's own vertical padding.
    func renderedColumnHeight(rows: Int, includeCaret: Bool) -> CGFloat {
        let rows = CGFloat(max(rows, 1))
        var height = rows * cell + (rows - 1) * runeSpacing
        if includeCaret {
            height += runeSpacing + caretHeight
        }
        return height + 2 * Self.columnVerticalPadding(showChrome: true)
    }

    /// Width `count` on-screen columns occupy, including inter-column spacing.
    func renderedWidth(columns count: Int) -> CGFloat {
        let count = CGFloat(max(count, 1))
        let colW = Self.columnWidth(cell: cell, showChrome: true)
        return count * colW + (count - 1) * columnSpacing
    }

    // MARK: Fitting

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
        let candidate = metrics(runeSize: runeSize, padding: 0)
        // The tallest column may be the last one, which also carries the caret —
        // so the caret is always budgeted for.
        let width = candidate.renderedWidth(columns: colCount)
        let height = candidate.renderedColumnHeight(rows: maxRows, includeCaret: true)
        return width <= availW && height <= availH
    }
}

// MARK: - Shared column layout (screen + export)

struct VerticalRuneColumnsView: View {
    let columns: [String]
    let runeSize: CGFloat
    let columnSpacing: CGFloat
    let runeSpacing: CGFloat
    let ink: Color
    let showChrome: Bool

    private var cell: CGFloat { CanvasMetrics.cell(runeSize: runeSize) }

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
                    .frame(width: CanvasMetrics.columnWidth(cell: cell, showChrome: showChrome))
                    .padding(.vertical, CanvasMetrics.columnVerticalPadding(showChrome: showChrome))
                    .background {
                        if showChrome {
                            // Theme.hairline is rose-tinted in Arcadia, so the
                            // column outlines carry the pink too.
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
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
            .frame(width: 2, height: CanvasMetrics.caretHeight(runeSize: runeSize))
            .frame(maxWidth: .infinity)
    }
}
