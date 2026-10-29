import Foundation

/// The double-space-for-period rule: a second space typed quickly after a word replaces
/// the first space with ". ".
///
/// Every guard here exists because dropping it produces visible damage — ".." after a
/// sentence, a period floating after a bare space, or a period appearing because the user
/// happened to pause between two words.
public enum PeriodShortcut {

    /// How long after the first space the second one still counts as a double-tap.
    /// Apple does not document its own value; this is tuned to be forgiving of a slow
    /// thumb without firing on two deliberately separate spaces.
    public static let window: TimeInterval = 1.0

    /// What VoiceOver speaks when the shortcut fires. A VoiceOver user with character
    /// feedback otherwise hears the space key twice and no cue that a period landed
    /// and shift armed; the sibling "Corrected X to Y" announcement already speaks.
    public static let announcement = "Period"

    /// The rule is deliberately blind to interleaving: it sees only (context, elapsed).
    /// Consecutiveness is the CALLER's obligation — any keystroke between the two
    /// spaces must reset the clock, because given a qualifying context and a fresh
    /// elapsed this rule will fire. The keyboard resets in `insert()` and
    /// `deleteBackward()`, on field changes, and on any host document change it did
    /// not itself cause (SpaceTracker distinguishes the echo of a local keystroke
    /// from an external edit).
    /// The context is an autoclosure so the common case — a space that is not part of a
    /// double-tap — never reads the host document at all: the window check runs first.
    public static func shouldSubstitute(contextBefore: @autoclosure () -> String?, sinceLastSpace: TimeInterval) -> Bool {
        guard sinceLastSpace <= window else { return false }

        // The space to be replaced, then — looking past any closing quote or bracket,
        // the way autocapitalisation does — the word character that proves a word
        // actually ended here. Only a letter or digit ends a word: a terminator, another
        // space, or a newline means nothing here wants a full stop, and `"stop." ` must
        // not become `"stop.". `.
        guard let context = contextBefore(), context.last == " " else { return false }
        let beforeSpace = context.dropLast().reversed()
        guard let preceding = beforeSpace.drop(while: { SentenceBoundary.closers.contains($0) }).first
        else { return false }
        return preceding.isLetter || preceding.isNumber
    }
}
