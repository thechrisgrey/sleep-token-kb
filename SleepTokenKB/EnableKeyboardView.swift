import SwiftUI
import UIKit

/// Walks the user through Settings so the extension appears in the system keyboard list.
struct EnableKeyboardView: View {
    /// Ceremonial step markers; five steps is exactly as far as this needs to count.
    private static let numerals = ["I", "II", "III", "IV", "V"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("iOS only lists third-party keyboards after you add them once. The steps below register Sleep Token KB system-wide.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkDim)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 18) {
                    step(
                        number: 0,
                        title: "Open Settings",
                        detail: "Tap the button below, or open the Settings app manually."
                    )

                    Button {
                        openSettings()
                    } label: {
                        Text("Open Settings")
                            .font(Theme.display(16))
                            .foregroundStyle(Theme.field)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.gold)
                            )
                    }
                    .buttonStyle(.plain)

                    step(
                        number: 1,
                        title: "General → Keyboard → Keyboards",
                        detail: "Settings → General → Keyboard → Keyboards."
                    )

                    step(
                        number: 2,
                        title: "Add New Keyboard…",
                        detail: "Tap Add New Keyboard…, then choose Sleep Token KB under THIRD-PARTY KEYBOARDS."
                    )

                    step(
                        number: 3,
                        title: "Optional: Full Access",
                        detail: "Not required for typing. Only turn on Full Access if a future version needs network or advanced pasteboard features. This build works with Full Access off."
                    )

                    step(
                        number: 4,
                        title: "Use it",
                        detail: "In any text field, long-press the globe key and select Sleep Token KB. Keys can show runes or ABC; text is always English. For rune messages, use Rune Pad."
                    )
                }
                .ritualCard()

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Troubleshooting")
                    VStack(alignment: .leading, spacing: 10) {
                        bullet("If the keyboard is missing from Add New Keyboard, force-quit Settings, reinstall this app, and try again.")
                        bullet("Keyboard extensions only appear after the host app has been installed at least once.")
                        bullet("On Simulator, press Command-K if the software keyboard is hidden.")
                    }
                    .ritualCard()
                }
            }
            .padding(16)
        }
        .background(RitualBackground())
        .navigationTitle("Enable keyboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(Self.numerals[number])
                .font(Theme.display(14, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 34, height: 34)
                .background(
                    Circle().fill(Theme.surfaceHigh)
                )
                .overlay(
                    Circle().strokeBorder(Theme.gold.opacity(0.28), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.display(16))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkDim)
                    .lineSpacing(2)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Theme.gold.opacity(0.6))
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.inkDim)
                .lineSpacing(2)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        EnableKeyboardView()
    }
    .preferredColorScheme(.dark)
    .tint(Theme.gold)
}
