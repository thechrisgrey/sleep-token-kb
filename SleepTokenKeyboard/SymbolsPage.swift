import SwiftUI

/// The 123 and #+= pages.
///
/// Stock flanks the short third row with the other symbol page's key on the left and
/// delete on the right. Ours used to run ten symbols across row three and put delete on
/// a row of its own, which is what made the keyboard grow 46pt whenever you tapped 123.
///
/// Its own file for the same reason EmojiPage left KeyboardRootView: the inputs are
/// plain values and closures with no root-view state, so the seam was already clean —
/// and `.swiftlint.yml` records the MARK-seam split, not a higher ceiling, as the answer
/// when KeyboardRootView.swift outgrows its file length.
struct SymbolsPage: View {
    let rows: [[String]]
    /// Title of the page this switches to — "#+=" from 123, "123" from #+=.
    let switchTitle: String
    let keyHeight: CGFloat
    let faceSize: CGFloat
    let onInsert: (String) -> Void
    let onSwitchPage: () -> Void
    let onBackspace: (Bool) -> Void

    /// Read here rather than passed, exactly as KeyboardRootView reads it: both sit in
    /// one hosting controller's trait environment, so there is only ever one answer.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        // Same GeometryReader-per-page shape as LetterPage, and for the same reason:
        // the page-switch key and delete are grid function keys, so they need the key
        // unit this width implies. Height is pinned by the caller.
        GeometryReader { geo in
            let unit = KeyboardMetrics.keyUnit(availableWidth: geo.size.width)
            let functionWidth = KeyboardMetrics.functionKeyWidth(keyUnit: unit)
            VStack(spacing: KeyboardMetrics.rowGap(compact: verticalSizeClass == .compact)) {
                ForEach(rows.indices, id: \.self) { index in
                    let isLastRow = index == rows.count - 1
                    HStack(spacing: KeyboardMetrics.keyGap) {
                        if isLastRow {
                            ChromeKeyButton(
                                content: .text(switchTitle),
                                fontSize: 14,
                                weight: .semibold,
                                label: switchTitle == "123"
                                    ? "Switch to numbers"
                                    : "Switch to more symbols",
                                action: onSwitchPage
                            )
                            .frame(width: functionWidth, height: keyHeight)
                        }

                        ForEach(rows[index], id: \.self) { symbol in
                            SymbolKeyButton(symbol: symbol, faceSize: faceSize) {
                                onInsert(symbol)
                            }
                            .frame(height: keyHeight)
                        }

                        if isLastRow {
                            BackspaceKey(
                                width: functionWidth,
                                keyHeight: keyHeight,
                                onBackspace: onBackspace
                            )
                        }
                    }
                }
            }
            .frame(width: geo.size.width, alignment: .top)
        }
    }
}
