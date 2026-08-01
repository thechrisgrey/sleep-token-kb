import SwiftUI
import UIKit

/// Walks the user through Settings so the extension appears in the system keyboard list.
struct EnableKeyboardView: View {
    /// The numeral medallion scales with the numeral inside it; fixed, the roman
    /// numeral outgrows its circle at large reading sizes.
    @ScaledMetric(relativeTo: .footnote) private var numeralSize: CGFloat = 34

    private struct SetupStep {
        let title: String
        let detail: String
    }

    /// Steps as data: numerals derive from position, so inserting or reordering a
    /// step can never trap on a hand-maintained index.
    private static let steps: [SetupStep] = [
        SetupStep(
            title: "Open Settings",
            detail: "Tap the button below, or open the Settings app manually."
        ),
        SetupStep(
            title: "Tap Keyboards",
            detail: "The button opens Ritual Keyboard's own page in Settings, which has a Keyboards row. Prefer the manual route? Settings → General → Keyboard → Keyboards."
        ),
        SetupStep(
            title: "Turn on Ritual Keyboard",
            detail: "Flip the Ritual Keyboard switch. On the manual route, tap Add New Keyboard… and choose Ritual Keyboard under THIRD-PARTY KEYBOARDS."
        ),
        SetupStep(
            title: "Optional: Full Access",
            detail: "The Allow Full Access switch sits on the same Ritual Keyboard screen as the switch from the last step. Only needed for key press haptics — iOS will not deliver haptic feedback from a keyboard extension without it. Everything else works either way: both layouts, all three key faces, the themes, and Rune Pad. It stays off until you turn it on."
        ),
        SetupStep(
            title: "Use it",
            detail: "In any text field, long-press the globe key and select Ritual Keyboard. Keys can show runes or ABC; text is always English. For rune messages, use Rune Pad."
        ),
    ]

    /// Ceremonial step markers, derived from position with a plain-number fallback
    /// should the list ever outgrow them.
    private static func numeral(_ index: Int) -> String {
        let numerals = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
        return index < numerals.count ? numerals[index] : "\(index + 1)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("iOS only lists third-party keyboards after you add them once. The steps below register Ritual Keyboard system-wide.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkDim)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Setup")
                    VStack(alignment: .leading, spacing: 18) {
                        step(0)

                        Button {
                            openSettings()
                        } label: {
                            Text("Open Settings")
                                .font(Theme.display(.callout))
                                .foregroundStyle(Theme.field)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.gold)
                                )
                        }
                        .buttonStyle(.plain)

                        ForEach(1..<Self.steps.count, id: \.self) { index in
                            step(index)
                        }
                    }
                    .ritualCard()
                    .overlay(alignment: .bottomTrailing) {
                        HiddenJerry(spot: .setupCard, height: 13)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "Troubleshooting")
                    VStack(alignment: .leading, spacing: 10) {
                        bullet("If the keyboard is missing from the Keyboards list, force-quit Settings, reinstall this app, and try again.")
                        bullet("Keyboard extensions only appear after the host app has been installed at least once.")
                        bullet("On Simulator, press Command-K if the software keyboard is hidden.")
                    }
                    .ritualCard()
                    .overlay(alignment: .topTrailing) {
                        HiddenJerry(spot: .troubleshooting, height: 12)
                    }
                }
            }
            .padding(16)
            .readableColumn()
        }
        .background(RitualBackground())
        .navigationTitle("Enable keyboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ index: Int) -> some View {
        let step = Self.steps[index]
        return HStack(alignment: .top, spacing: 14) {
            Text(Self.numeral(index))
                .font(Theme.display(.footnote, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: numeralSize, height: numeralSize)
                .background(
                    Circle().fill(Theme.surfaceHigh)
                )
                .overlay(
                    Circle().strokeBorder(Theme.gold.opacity(0.28), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(Theme.display(.callout))
                    .foregroundStyle(Theme.ink)
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkDim)
                    .lineSpacing(2)
            }
        }
        // One element per step: VoiceOver hears position and content together
        // instead of a bare roman numeral followed by loose text.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index + 1) of \(Self.steps.count): \(step.title). \(step.detail)")
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
