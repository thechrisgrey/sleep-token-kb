import UIKit

/// Decides the shift state to adopt for the next character, from the host field's
/// autocapitalisation preference, the text already in front of the cursor, and — since
/// the 2026-07-31 audit — the *provenance* of the current state.
///
/// Provenance is the load-bearing part. This rule both produces engaged states (arming
/// shift at a sentence start) and must preserve engaged states the user produced by
/// hand. Without knowing which is which, an auto-armed shift ratchets: nothing can ever
/// release it, deleting back into a word keeps the next letter uppercase, and a caps
/// lock inherited from an `.allCharacters` field outlives the field. So: a MANUAL state
/// outranks the field and is preserved without even reading the document; an AUTO state
/// is re-derived from context on every call, exactly as if it had never been set.
///
/// Kept as a pure function rather than living in the view because the interesting cases
/// are all textual and none of them need a live `UITextDocumentProxy` to answer.
public enum Autocapitalization {

    /// Characters that end a sentence for capitalisation purposes.
    private static let terminators: Set<Character> = [".", "!", "?"]

    /// Closing punctuation that may legally sit between the terminator and the space:
    /// `He said "stop." ` still ends a sentence. Straight quotes double as openers, so
    /// an opener directly before a space (`He said. " `) is conservatively not treated
    /// as a boundary — a miss there costs one lowercase letter, not a wrong capital.
    private static let closers: Set<Character> = ["\"", "'", ")", "]", "}", "\u{201D}", "\u{2019}"]

    /// The context arrives as an autoclosure so the host document is read only when the
    /// decision actually depends on it — never for `.none` fields, never when a manual
    /// engaged state short-circuits the derivation. The tests pin this.
    public static func nextShift(
        for type: UITextAutocapitalizationType,
        contextBefore: @autoclosure () -> String?,
        current: ShiftState,
        autoArmed: Bool
    ) -> ShiftState {
        // A manually engaged state is a deliberate user act and outranks the field.
        // An auto-armed one was produced by this very rule and is re-derived below —
        // preserving it is the ratchet the audit found.
        if current != .off && !autoArmed { return current }

        switch type {
        case .allCharacters:
            return .capsLocked
        case .words:
            return isAtWordStart(contextBefore()) ? .shifted : .off
        case .sentences:
            return isAtSentenceStart(contextBefore()) ? .shifted : .off
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

        // A newline starts a new sentence whatever preceded it — list items and message
        // bodies rarely end their lines with a full stop.
        if last.isNewline { return true }

        // Otherwise it takes a terminator *and* the space after it. Arming on the bare
        // terminator would capitalise the fractional part of "3.14".
        guard last.isWhitespace else { return false }

        // Scan back over the whitespace, then over any closing punctuation, and test
        // what remains. A field holding nothing but whitespace is still at its start.
        let trailing = context.reversed().drop(while: \.isWhitespace)
        guard let meaningful = trailing.drop(while: { closers.contains($0) }).first else {
            return trailing.first == nil
        }
        return terminators.contains(meaningful)
    }
}
