import UIKit

/// What the return keycap should read for the field currently being edited.
///
/// `UIReturnKeyType` is not `CaseIterable`, so this switch is the only enumeration of it
/// in the project; the matching test spells the list out again deliberately, so a case
/// dropped from here fails rather than silently falling through to "return".
public enum ReturnKeyTitle {

    public static func title(for type: UIReturnKeyType) -> String {
        switch type {
        case .go: "Go"
        // google and yahoo are legacy spellings of "this is a search field". Neither should
        // put a search engine's name on a keycap.
        case .google, .search, .yahoo: "Search"
        case .join: "Join"
        case .next: "Next"
        case .route: "Route"
        case .send: "Send"
        case .done: "Done"
        case .emergencyCall: "Emergency"
        case .continue: "Continue"
        // Lowercase to match the system keyboard, and to sit correctly beside "space".
        case .default: "return"
        @unknown default: "return"
        }
    }

    /// VoiceOver reads this rather than the cap. Only the lowercase default needs
    /// promoting; every other title is already a word spoken as written.
    public static func accessibilityLabel(for type: UIReturnKeyType) -> String {
        type == .default ? "Return" : title(for: type)
    }
}
