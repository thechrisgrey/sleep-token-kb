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

    public static func shouldSubstitute(contextBefore: String?, sinceLastSpace: TimeInterval) -> Bool {
        guard sinceLastSpace <= window else { return false }

        // Two characters minimum: the space to be replaced, and the word character that
        // proves a word actually ended here.
        guard let contextBefore, contextBefore.count >= 2 else { return false }

        var characters = Array(contextBefore)
        guard characters.removeLast() == " " else { return false }
        guard let preceding = characters.last else { return false }

        // Only a letter or digit ends a word. Anything else — punctuation, another space,
        // a newline — means there is nothing here that wants a full stop.
        return preceding.isLetter || preceding.isNumber
    }
}
