import SwiftUI

/// The emoji page.
///
/// Apple's own emoji keyboard cannot be presented from a third-party extension — no
/// public API selects an input mode — so this is ours: a scrolling grid over our own
/// catalog, inserting plain text through the same path as every other key.
///
/// Its own file for the same reason RuneCanvas left RunePadView: the inputs are plain
/// values and closures with no root-view state, so the seam was already clean.
struct EmojiPage: View {
    @Binding var category: EmojiCategory
    let recents: [String]
    let cellHeight: CGFloat
    let onInsert: (String) -> Void
    let onBackspace: (Bool) -> Void

    /// Height of the category strip. Sized to clear the 44pt touch target while leaving
    /// the grid the bulk of a page budget that is already fixed.
    private static let stripHeight: CGFloat = 44

    /// Read here rather than passed, exactly as KeyboardRootView reads it. See LetterPage.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The recents order this visit shows, frozen when the tab is opened. The root
    /// promotes a tapped emoji to the front of the LIVE list at once, and rendering
    /// that list reordered the grid under the thumb: tap the fifth cell and cells one
    /// to four slid right while the finger was still down, so a second tap on the
    /// same spot inserted whatever had been fourth. Stock holds the order for the
    /// visit and shows the new order next time the tab opens; so does this.
    @State private var shownRecents: [String]

    init(
        category: Binding<EmojiCategory>,
        recents: [String],
        cellHeight: CGFloat,
        onInsert: @escaping (String) -> Void,
        onBackspace: @escaping (Bool) -> Void
    ) {
        _category = category
        self.recents = recents
        self.cellHeight = cellHeight
        self.onInsert = onInsert
        self.onBackspace = onBackspace
        // Seeded on arrival, here rather than in onAppear so the first frame already
        // has the grid; `State(initialValue:)` is honoured once per visit, which is
        // exactly the freeze.
        _shownRecents = State(initialValue: recents)
    }

    private var compact: Bool { verticalSizeClass == .compact }

    private var entries: [String] {
        category == .recents ? shownRecents : EmojiCatalog.emoji(in: category)
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowGap(compact: compact)) {
            if entries.isEmpty {
                // Recents on a fresh install. Teach the interface rather than showing
                // an empty box. The clock is decorative: the caption is the message,
                // and the combined element must not open with "Clock".
                VStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Emoji you use will appear here")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(
                            .adaptive(minimum: 38),
                            spacing: KeyboardMetrics.keyGap
                        )],
                        spacing: KeyboardMetrics.rowGap(compact: compact)
                    ) {
                        ForEach(entries, id: \.self) { emoji in
                            Button { onInsert(emoji) } label: {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: cellHeight)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(emoji)
                            .accessibilityAddTraits(.isKeyboardKey)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: KeyboardMetrics.keyGap) {
                // All ten tabs share the row, the way stock's strip does: every
                // category always visible, none hidden past the edge of an
                // indicator-less scroll. Tabs land around 32-38pt wide across
                // current iPhones — stock's own tab size — and the full-height
                // frame keeps the target tall.
                HStack(spacing: 2) {
                    ForEach(EmojiCategory.allCases) { tab in
                        Button { category = tab } label: {
                            Image(systemName: tab.symbolName)
                                .font(.footnote)
                                .foregroundStyle(
                                    tab == category ? Color.primary : Color.secondary
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: Self.stripHeight)
                                .contentShape(Rectangle())
                                // The selected tab sits on the active fill — the same
                                // "this one is on" the options panel and the emoji key
                                // use — not on a tint change alone. Stock puts a filled
                                // rounded square behind the current category.
                                .background(
                                    RoundedRectangle(
                                        cornerRadius: KeyboardMetrics.keyCornerRadius,
                                        style: .continuous
                                    )
                                    .fill(tab == category ? KeyPalette.active : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.accessibilityLabel)
                        .accessibilityAddTraits(
                            tab == category ? [.isButton, .isSelected] : .isButton
                        )
                    }
                }

                BackspaceKey(keyHeight: Self.stripHeight, onBackspace: onBackspace)
            }
            .frame(height: Self.stripHeight)
        }
        // The live list is consulted again only when the tab changes.
        .onChange(of: category) { shownRecents = recents }
    }
}
