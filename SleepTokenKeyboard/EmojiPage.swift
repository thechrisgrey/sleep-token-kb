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

    private var entries: [String] {
        category == .recents ? recents : EmojiCatalog.emoji(in: category)
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowGap) {
            if entries.isEmpty {
                // Recents on a fresh install. Teach the interface rather than showing
                // an empty box.
                VStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.title3)
                        .foregroundStyle(.secondary)
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
                        spacing: KeyboardMetrics.rowGap
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
    }
}
