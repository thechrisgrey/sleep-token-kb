import SwiftUI
import UIKit

/// Walks the user through Settings so the extension appears in the system keyboard list.
struct EnableKeyboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro

                step(
                    number: 1,
                    title: "Open Settings",
                    detail: "Tap the button below, or open the Settings app manually."
                )

                Button {
                    openSettings()
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                step(
                    number: 2,
                    title: "General → Keyboard → Keyboards",
                    detail: "Settings → General → Keyboard → Keyboards."
                )

                step(
                    number: 3,
                    title: "Add New Keyboard…",
                    detail: "Tap Add New Keyboard…, then choose SleepTokenKeyboard / SleepTokenFanKB under THIRD-PARTY KEYBOARDS."
                )

                step(
                    number: 4,
                    title: "Optional: Full Access",
                    detail: "Not required for typing. Only turn on Full Access if a future version needs network or advanced pasteboard features. This build works with Full Access off."
                )

                step(
                    number: 5,
                    title: "Use it",
                    detail: "In any text field, long-press the globe key and select SleepTokenKeyboard. Keys can show runes or ABC; text is always English. For rune messages, use Rune Pad → Copy Image."
                )

                Divider().padding(.vertical, 4)

                Text("Troubleshooting")
                    .font(.headline)

                bullet("If the keyboard is missing from Add New Keyboard, force-quit Settings, reinstall this app, and try again.")
                bullet("Keyboard extensions only appear after the host app has been installed at least once.")
                bullet("On Simulator, press Command-K if the software keyboard is hidden.")
            }
            .padding()
        }
        .navigationTitle("Enable keyboard")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var intro: some View {
        Text("iOS only lists third-party keyboards after you add them once. The steps below register SleepTokenKeyboard system-wide.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func step(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
}
