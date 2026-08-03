import Foundation

/// Whether the welcome screen shows the "Enable the keyboard" card.
///
/// Detection reads the system's enabled-keyboards preference (the caller passes
/// `UserDefaults.standard.stringArray(forKey: "AppleKeyboards")`), which is not
/// formally documented — so the rule degrades toward showing: an unreadable or
/// empty list keeps the card, and the enable guide's manual hide is the human
/// override for a read that lies. Pure, so every branch is testable.
enum EnableThreshold {
    static let keyboardBundleID = "ai.altivum.SleepTokenKB.SleepTokenKeyboard"
    static let manuallyHiddenKey = "enableCardManuallyHidden"

    static func showsEnableCard(enabledKeyboards: [String]?, manuallyHidden: Bool) -> Bool {
        if manuallyHidden { return false }
        guard let enabledKeyboards, !enabledKeyboards.isEmpty else { return true }
        return !enabledKeyboards.contains(keyboardBundleID)
    }
}
