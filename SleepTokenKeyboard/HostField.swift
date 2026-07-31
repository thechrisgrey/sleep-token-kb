import UIKit

/// Live access to the field currently being edited.
///
/// Every member is a closure rather than a stored value for the same reason the insert and
/// delete actions are: `UITextDocumentProxy` changes under the keyboard between keystrokes,
/// so anything snapshotted when the root view was built is stale by the next tap. Reading
/// through a closure means the answer is always the one the host would give right now.
struct HostField {
    var contextBefore: () -> String?
    var returnKeyType: () -> UIReturnKeyType

    /// False when the field asked for `enablesReturnKeyAutomatically` and holds no
    /// text yet — the system keyboard dims and disables return there, so this one does.
    var returnKeyEnabled: () -> Bool
    var autocapitalization: () -> UITextAutocapitalizationType

    /// Whether the user has granted Full Access in Settings.
    ///
    /// The extension declares `RequestsOpenAccess`, but declaring it only makes the toggle
    /// appear — each user still has to turn it on, and most never will. Anything that
    /// depends on it has to degrade rather than assume.
    var hasFullAccess: () -> Bool
}
