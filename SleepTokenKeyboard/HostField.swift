import UIKit

/// Live access to the field currently being edited.
///
/// Every member is a closure rather than a stored value for the same reason the insert and
/// delete actions are: `UITextDocumentProxy` changes under the keyboard between keystrokes,
/// so anything snapshotted when the root view was built is stale by the next tap. Reading
/// through a closure means the answer is always the one the host would give right now.
struct HostField {
    var contextBefore: () -> String?

    /// What follows the caret. Answers the one question correction must ask before
    /// every suggestion and silent replacement: is the caret INSIDE a word? The
    /// current word is derived from `contextBefore` alone, so without this read a
    /// caret parked mid-word would get its left fragment "corrected" into the
    /// middle of a word the user already finished.
    var contextAfter: () -> String?

    var returnKeyType: () -> UIReturnKeyType

    /// False when the field asked for `enablesReturnKeyAutomatically` and holds no
    /// text yet — the system keyboard dims and disables return there, so this one does.
    var returnKeyEnabled: () -> Bool
    var autocapitalization: () -> UITextAutocapitalizationType

    /// Whether this field wants spelling help at all.
    ///
    /// False for passwords, one-time codes, URLs, email addresses, and anything that
    /// declares `autocorrectionType == .no` or `spellCheckingType == .no`. The stock
    /// keyboard goes quiet in those fields; correcting a password would be worse than
    /// offering nothing.
    var correctionAllowed: () -> Bool

    /// Whether the field asked for a number pad.
    ///
    /// A custom keyboard replaces every keyboard type, so a phone-number or amount field
    /// gets these same letter and symbol pages. In one, the symbols page is where the
    /// user means to stay — which is why the space bar's return to letters stands down
    /// there. See `PageAfterSpace`.
    var usesNumberPad: () -> Bool

    /// Whether the user has granted Full Access in Settings.
    ///
    /// The extension declares `RequestsOpenAccess`, but declaring it only makes the toggle
    /// appear — each user still has to turn it on, and most never will. Anything that
    /// depends on it has to degrade rather than assume.
    var hasFullAccess: () -> Bool
}
