import Foundation

/// How a decoded glide word lands in the document.
public enum GlideCommit {

    public struct Insertion: Equatable {
        /// Everything the proxy receives, possibly space-prefixed.
        public let text: String
        /// The cased word alone: the suggestion-bar literal, and the character
        /// count a whole-word backspace removes (the auto-space stays, as stock
        /// leaves it).
        public let word: String
    }

    /// The word as this shift state would type it. Split out so alternates can
    /// be cased identically to the committed head — the bar must not read
    /// "Hello" beside "jello" at a sentence start.
    public static func cased(_ word: String, shift: ShiftState) -> String {
        switch shift {
        case .off: word
        case .shifted: word.prefix(1).uppercased() + word.dropFirst()
        case .capsLocked: word.uppercased()
        }
    }

    /// Auto-space joins CONSECUTIVE glides only — "context ends in a letter and
    /// the last insert was also a glide" (spec). A glide after tapped text, after
    /// punctuation, or at a field start inserts bare.
    public static func insertion(
        word: String,
        shift: ShiftState,
        contextBefore: String?,
        lastInsertWasGlide: Bool
    ) -> Insertion {
        let cased = Self.cased(word, shift: shift)
        let needsSpace = lastInsertWasGlide && (contextBefore?.last?.isLetter ?? false)
        return Insertion(text: needsSpace ? " " + cased : cased, word: cased)
    }
}

/// Arms exactly one whole-word backspace after a glide commit, with the same
/// local-echo discipline as `SpaceTracker`: the settle of this keyboard's own
/// edit passes through silently, any external host change disarms.
public final class GlideUndo {
    private var wordLength: Int?
    private var pendingLocalEcho = false

    public init() {}

    public var isArmed: Bool { wordLength != nil }

    public func record(wordLength length: Int) {
        wordLength = length
    }

    /// The armed length, exactly once. The backspace that consumes it deletes
    /// this many characters instead of one.
    public func consume() -> Int? {
        defer { wordLength = nil }
        return wordLength
    }

    /// Any keystroke that is not the consuming backspace, and any field change.
    public func interrupt() {
        wordLength = nil
    }

    public func noteLocalChange() {
        pendingLocalEcho = true
    }

    public func hostTextDidChange() {
        if pendingLocalEcho {
            pendingLocalEcho = false
        } else {
            wordLength = nil
        }
    }
}
