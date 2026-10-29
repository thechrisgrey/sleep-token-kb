import SwiftUI

/// Layout and key face, shown over the keys when the emoji key is held.
///
/// Rendered inside the input view rather than as a popover or sheet: a keyboard
/// extension has no window of its own to present into, and system presentation from
/// an input view is where keyboards go to hang. Its own file because its inputs are
/// plain values and closures — the same seam EmojiPage and SymbolsPage crossed.
struct KeyboardOptionsPanel: View {
    let layoutMode: LayoutMode
    let keyFaceStyle: KeyFaceStyle
    let onSelectLayout: (LayoutMode) -> Void
    let onSelectKeyFace: (KeyFaceStyle) -> Void
    let onDismiss: () -> Void
    let haptic: () -> Void

    private struct Option {
        let title: String
        /// The full name VoiceOver speaks. "Rune·A" and "A–Z" read unpredictably, so
        /// every option pairs its chrome title with a spoken one, as SettingsView does.
        let spokenName: String
        let isSelected: Bool
    }

    var body: some View {
        ZStack {
            KeyPalette.field.opacity(0.96)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 10) {
                row(
                    title: "Layout",
                    options: LayoutMode.allCases.map {
                        Option(title: $0.shortTitle, spokenName: $0.accessibilityLabel, isSelected: $0 == layoutMode)
                    }
                ) { index in
                    onSelectLayout(LayoutMode.allCases[index])
                }

                row(
                    title: "Key face",
                    options: KeyFaceStyle.allCases.map {
                        Option(title: $0.shortTitle, spokenName: $0.title, isSelected: $0 == keyFaceStyle)
                    }
                ) { index in
                    onSelectKeyFace(KeyFaceStyle.allCases[index])
                }

                // Done is a key like the options above it: the same keycap chassis, the
                // same press feedback, the same 44pt floor. The automatic button style
                // rendered system blue at ~2.7:1 on the light field with a text-height
                // hit area.
                Button {
                    haptic()
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: KeyboardMetrics.minimumTouchTarget)
                        .keycap(fill: KeyPalette.function)
                }
                .buttonStyle(KeyPressStyle())
                .padding(.top, 2)
            }
            .padding(.horizontal, 12)
        }
        .accessibilityAddTraits(.isModal)
        // The panel is modal; the two-finger scrub that VoiceOver users expect to
        // dismiss one has to land somewhere.
        .accessibilityAction(.escape, onDismiss)
    }

    private func row(
        title: String,
        options: [Option],
        select: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 4) {
            // Primary, not secondary: caption2 over the 96% field measured ~2.9:1 in
            // light mode, and these are the only words that say what the row is.
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
            HStack(spacing: KeyboardMetrics.keyGap) {
                ForEach(options.indices, id: \.self) { index in
                    let option = options[index]
                    Button {
                        haptic()
                        select(index)
                    } label: {
                        Text(option.title)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: KeyboardMetrics.minimumTouchTarget)
                            .keycap(fill: option.isSelected ? KeyPalette.active : KeyPalette.function)
                    }
                    .buttonStyle(KeyPressStyle())
                    .accessibilityLabel(option.spokenName)
                    .accessibilityAddTraits(option.isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}
