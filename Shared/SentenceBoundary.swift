import Foundation

/// The punctuation vocabulary two text-entry rules share.
///
/// `Autocapitalization` looks back past a closer to find the terminator that ends a
/// sentence; `PeriodShortcut` looks back past the same closer to find the word that the
/// double space ends. They used to keep separate lists — the shortcut's was empty — so
/// `(see above)` plus two quick spaces armed shift but refused the period. One set, read
/// by both, so a closer added for one rule cannot be missed by the other.
public enum SentenceBoundary {

    /// Characters that end a sentence for capitalisation purposes.
    public static let terminators: Set<Character> = [".", "!", "?"]

    /// Closing punctuation that may legally sit between a word (or its terminator) and
    /// the space after it: `He said "stop." ` still ends a sentence, and `(see above) `
    /// still ends a word. Straight quotes double as openers, so an opener directly
    /// before a space (`He said. " `) is conservatively treated as a closer too — a miss
    /// there costs one lowercase letter or one missing period, never a wrong capital.
    public static let closers: Set<Character> = ["\"", "'", ")", "]", "}", "\u{201D}", "\u{2019}"]
}
