import Foundation

/// The road back from a silent replacement.
///
/// Stock offers the word you actually typed in the bar the moment you backspace into
/// the corrected one. The engine's memo only runs one way ("teh" maps to ["the"]), so
/// without this the bar saw "the", a known word, and rendered nothing; recovery was
/// three backspaces, a retype, and "Keep teh". One slot, like stock: only the most
/// recent replacement can be taken back, and only while the caret sits on it.
public struct CorrectionUndo: Equatable {
    private var typed: String?
    private var replacement: String?

    public init() {}

    /// A boundary replacement just landed.
    public mutating func record(typed: String, replacement: String) {
        self.typed = typed
        self.replacement = replacement
    }

    /// The typed word to offer when the word under the caret is exactly the
    /// replacement, else nil. Exact, case and all: the user types on and the word is
    /// theirs again; a sentence-start "Teh" comes back as the capital they typed.
    public func original(ifCurrentWordIs word: String) -> String? {
        guard !word.isEmpty, word == replacement else { return nil }
        return typed
    }

    /// Extending the word, switching fields, or taking the offer all end it.
    public mutating func interrupt() {
        typed = nil
        replacement = nil
    }
}
