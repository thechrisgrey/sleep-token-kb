import SwiftUI
import UIKit

/// Vertical ritual writing + export as a transparent image for other apps.
/// Long words / many columns automatically scale down so the canvas stays in view.
struct RunePadView: View {
    /// Words separated by spaces; each word is one vertical column.
    @State private var text = ""
    @State private var copyStatus: String?
    @State private var isExporting = false

    private let preferredRuneSize: CGFloat = 32
    private let rows: [[SleepTokenLetter]] = KeyboardLayout.qwertyRows

    var body: some View {
        VStack(spacing: 12) {
            Text("Write top to bottom. Space starts a new column. Long text shrinks to fit. Copy Image pastes into Messages, Notes, Reminders, and more.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
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
                    showChrome: true
                )
                .padding(metrics.padding)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
                .animation(.easeOut(duration: 0.15), value: text)
            }
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 280)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )

            letterPad

            if let copyStatus {
                Text(copyStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .navigationTitle("Rune Pad")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { _ = RuneFont.registerIfNeeded() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Clear") { text = ""; copyStatus = nil }
                    .disabled(text.isEmpty)

                Button {
                    Task { await copyAsTransparentImage() }
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Text("Copy Image")
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isExporting)
            }
        }
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
                            Text(letter.upperLatin)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(uiColor: .systemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, index == 1 ? 12 : 0)
            }

            HStack(spacing: 8) {
                Button(action: startNewColumn) {
                    Text("space · new column")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(uiColor: .systemGray5))
                        )
                }
                .buttonStyle(.plain)

                Button(action: deleteBackward) {
                    Image(systemName: "delete.left")
                        .frame(width: 56, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(uiColor: .systemGray5))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemBackground))
        )
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

    @MainActor
    private func copyAsTransparentImage() async {
        isExporting = true
        defer { isExporting = false }

        _ = RuneFont.registerIfNeeded()

        let exportColumns = columns.filter { !$0.isEmpty }
        // Export at a comfortable resolution (not the on-screen shrunk size).
        let exportMetrics = CanvasMetrics.forExport(
            columns: exportColumns,
            preferredRuneSize: preferredRuneSize
        )

        let content = VerticalRuneColumnsView(
            columns: exportColumns,
            runeSize: exportMetrics.runeSize,
            columnSpacing: exportMetrics.columnSpacing,
            runeSpacing: exportMetrics.runeSpacing,
            showChrome: false
        )
        .padding(24)
        .background(Color.clear)

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = false

        try? await Task.sleep(nanoseconds: 50_000_000)

        guard let image = renderer.uiImage else {
            copyStatus = "Could not render image. Try again."
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

        copyStatus = "Image copied. Paste into Messages, Notes, Reminders, and other apps."
    }
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
                                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
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
            SymbolGlyphView(letter: letter, foreground: .primary)
                .frame(width: cell, height: cell)
                .frame(maxWidth: .infinity)
        } else {
            Text(String(character))
                .font(RuneFont.font(size: runeSize))
                .foregroundStyle(.primary)
                .frame(width: cell, height: cell, alignment: .center)
                .frame(maxWidth: .infinity)
        }
    }

    private var caret: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.accentColor.opacity(0.8))
            .frame(width: 2, height: max(8, runeSize * 0.55))
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        RunePadView()
    }
}
