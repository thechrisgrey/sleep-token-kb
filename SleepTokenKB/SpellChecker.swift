import UIKit

/// Spell check for Rune Pad's live Latin read-back.
///
/// This logic used to sit inline in a computed property reached from `body`, so a fresh
/// `UITextChecker` was allocated and every completed word re-checked on each keystroke —
/// synchronous main-thread work in the typing path, growing with the length of the
/// composition. One checker, memoized per word, does the same job.
///
/// The rules it encodes are the two that actually matter, and both are pinned by
/// `SpellCheckerTests`: which words count as finished, and which finished words are
/// flagged.
final class SpellChecker {
    /// `UITextChecker` is expensive to construct. Holding one is the point of this type.
    private let checker = UITextChecker()

    /// Per-word verdicts. A composition holds a handful of distinct words; the cap only
    /// exists so a very long session cannot grow this without bound.
    private var verdicts: [String: Bool] = [:]
    private static let cacheLimit = 512

    /// The words eligible to be judged.
    ///
    /// The trailing column is still being typed until a space ends it, so judging it
    /// mid-word would flicker amber on every keystroke.
    static func completedWords(_ words: [String], textEndsWithSpace: Bool) -> [String] {
        guard !words.isEmpty else { return [] }
        return textEndsWithSpace ? words : Array(words.dropLast())
    }

    /// The subset the system dictionary does not recognise.
    ///
    /// A word passes if either its lowercase *or* capitalized form is accepted, so
    /// proper nouns (EUCLID, ARCADIA) are not false-flagged. Single letters are
    /// legitimate columns and are never judged.
    func misspelled(in words: [String]) -> Set<String> {
        var flagged: Set<String> = []
        for word in words where word.count > 1 && isMisspelled(word) {
            flagged.insert(word)
        }
        return flagged
    }

    private func isMisspelled(_ word: String) -> Bool {
        if let cached = verdicts[word] { return cached }
        let verdict = isUnknown(word) && isUnknown(word.capitalized)
        if verdicts.count >= Self.cacheLimit {
            verdicts.removeAll(keepingCapacity: true)
        }
        verdicts[word] = verdict
        return verdict
    }

    private func isUnknown(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        return checker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: "en_US"
        ).location != NSNotFound
    }
}
