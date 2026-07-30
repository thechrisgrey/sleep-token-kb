import UIKit

/// Decides the shift state to adopt for the next character, from the host field's
/// autocapitalisation preference and the text already in front of the cursor.
///
/// Kept as a pure function rather than living in the view because the interesting cases
/// are all textual ("does this context end a sentence?") and none of them need a live
/// `UITextDocumentProxy` to answer.
public enum Autocapitalization {

    /// Characters that end a sentence for capitalisation purposes.
    private static let terminators: Set<Character> = [".", "!", "?"]

    public static func nextShift(
        for type: UITextAutocapitalizationType,
        contextBefore: String?,
        current: ShiftState
    ) -> ShiftState {
        // Both engaged states are deliberate user acts and outrank the field's preference.
        // Caps lock persists until tapped off; a one-shot shift is consumed by the next
        // insert, so preserving it here cannot strand the keyboard in uppercase.
        if current == .capsLocked { return .capsLocked }
        if current == .shifted { return .shifted }

        switch type {
        case .allCharacters:
            return .capsLocked
        case .words:
            return isAtWordStart(contextBefore) ? .shifted : .off
        case .sentences:
            return isAtSentenceStart(contextBefore) ? .shifted : .off
        case .none:
            return .off
        @unknown default:
            return .off
        }
    }

    private static func isAtWordStart(_ context: String?) -> Bool {
        guard let context, let last = context.last else { return true }
        return last.isWhitespace
    }

    private static func isAtSentenceStart(_ context: String?) -> Bool {
        guard let context, let last = context.last else { return true }

        // A field holding nothing but whitespace is still at its start.
        if context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }

        // A newline starts a new sentence whatever preceded it — list items and message
        // bodies rarely end their lines with a full stop.
        if last.isNewline { return true }

        // Otherwise it takes a terminator *and* the space after it. Arming on the bare
        // terminator would capitalise the fractional part of "3.14".
        guard last.isWhitespace else { return false }
        guard let lastMeaningful = context.reversed().first(where: { !$0.isWhitespace }) else {
            return true
        }
        return terminators.contains(lastMeaningful)
    }
}
