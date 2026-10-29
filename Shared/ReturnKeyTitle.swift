import UIKit

/// What the return keycap should read for the field currently being edited.
///
/// `UIReturnKeyType` is not `CaseIterable`, so this switch is the only enumeration of it
/// in the project; the matching test spells the list out again deliberately, so a case
/// dropped from here fails rather than silently falling through to "return".
public enum ReturnKeyTitle {

    /// Lowercase throughout, to match the system keyboard: since iOS 13 stock draws
    /// "return", "go", "search", "send" and "done" all in lowercase, and the cap sits
    /// beside "space". The spoken label (below) carries the capital.
    public static func title(for type: UIReturnKeyType) -> String {
        switch type {
        case .go: "go"
        // google and yahoo are legacy spellings of "this is a search field". Neither should
        // put a search engine's name on a keycap.
        case .google, .search, .yahoo: "search"
        case .join: "join"
        case .next: "next"
        case .route: "route"
        case .send: "send"
        case .done: "done"
        case .emergencyCall: "emergency"
        case .continue: "continue"
        case .default: "return"
        @unknown default: "return"
        }
    }

    /// Whether stock paints this return key as a tinted action key with a white title
    /// rather than the function grey. The field actions do; a plain return and "next"
    /// — which only moves focus — stay grey, and emergency call is its own red key on
    /// stock that this keyboard does not imitate.
    public static func isAction(for type: UIReturnKeyType) -> Bool {
        switch type {
        case .go, .google, .search, .yahoo, .join, .route, .send, .done, .continue: true
        case .default, .next, .emergencyCall: false
        @unknown default: false
        }
    }

    /// VoiceOver reads this rather than the cap: the cap is lowercase to match stock,
    /// the spoken word carries the capital.
    public static func accessibilityLabel(for type: UIReturnKeyType) -> String {
        title(for: type).capitalized
    }
}
