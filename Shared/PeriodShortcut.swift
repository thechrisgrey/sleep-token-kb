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

    /// The rule is deliberately blind to interleaving: it sees only (context, elapsed).
    /// Consecutiveness is the CALLER's obligation — any keystroke between the two
    /// spaces must reset the clock, because given a qualifying context and a fresh
    /// elapsed this rule will fire. The keyboard resets in `insert()`, `deleteBackward()`
    /// and on field changes.
    /// The context is an autoclosure so the common case — a space that is not part of a
    /// double-tap — never reads the host document at all: the window check runs first.
    public static func shouldSubstitute(contextBefore: @autoclosure () -> String?, sinceLastSpace: TimeInterval) -> Bool {
        guard sinceLastSpace <= window else { return false }

        // Two characters answer everything: the space to be replaced, and the word
        // character that proves a word actually ended here. Only a letter or digit ends
        // a word — punctuation, another space, or a newline means nothing here wants a
        // full stop.
        guard let context = contextBefore(),
              context.last == " ",
              let preceding = context.dropLast().last else { return false }
        return preceding.isLetter || preceding.isNumber
    }
}
