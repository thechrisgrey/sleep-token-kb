import UIKit

/// Where a word starts and stops, as the keyboard sees it through the document proxy.
public enum WordBoundary {
    /// Everything that ends a word. The apostrophe is deliberately absent: without it
    /// "don't" reads as "don" plus "t" and every contraction gets flagged.
    private static let boundaries = CharacterSet
        .whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(.symbols)
        .subtracting(CharacterSet(charactersIn: "'’"))

    public static func isBoundary(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { boundaries.contains($0) }
    }

    /// The in-progress word immediately before the caret, or "" if the caret sits on a
    /// boundary. Derived from `documentContextBeforeInput`, which is the only view of the
    /// document a keyboard extension gets.
    public static func currentWord(in contextBefore: String) -> String {
        String(contextBefore.reversed().prefix { !isBoundary($0) }.reversed())
    }

    /// True when the caret sits inside a word: the character right of it continues the
    /// run the caret interrupted. `currentWord` sees only the fragment LEFT of the caret,
    /// so suggesting or replacing there splices into text the user already finished —
    /// "wor|lds" corrected on space becomes "worklds". Stock stands down mid-word, and so
    /// does everything that consults this. A nil or empty context-after is the end of the
    /// document, never mid-word.
    public static func caretIsInsideWord(contextAfter: String?) -> Bool {
        guard let next = contextAfter?.first else { return false }
        return !isBoundary(next)
    }
}

/// Candidates for the bar above the keys.
public struct SuggestionSet: Equatable {
    /// What the user actually typed. Stock always keeps this available so a correction
    /// can never be forced; it is the whole safety valve.
    public let literal: String
    /// Best first. Spell suggestions offer up to two corrections; a glide's
    /// alternates offer up to three. The bar lays out whatever it is given.
    public let candidates: [String]

    public var isEmpty: Bool { literal.isEmpty && candidates.isEmpty }

    public init(literal: String, candidates: [String]) {
        self.literal = literal
        self.candidates = candidates
    }
}

/// Spelling correction for the keyboard extension.
///
/// iOS does not vend its autocorrect engine to third-party keyboards — there is no API
/// that asks the system what it would correct a word to — so this is built from what IS
/// public: `UITextChecker` for the dictionary and its guesses. The blue-underline UI the
/// stock keyboard shows inside the text field is first-party and unreachable from an
/// extension, whose entire document surface is `insertText` / `deleteBackward` plus
/// reads; a candidate bar over the keys is what every third-party keyboard does instead.
public final class SuggestionEngine {
    /// `UITextChecker` is expensive to construct, and this is reached from the typing
    /// path on every keystroke. One instance, results memoised per word.
    private let checker = UITextChecker()
    private var guessCache: [String: [String]] = [:]
    private static let cacheLimit = 512

    /// Words the user explicitly kept. Rejecting a correction has to stick, or the
    /// keyboard argues with them about their own vocabulary forever.
    private var kept: Set<String> = []

    /// Below this length a "misspelling" is usually deliberate — initials, "ok", "hm" —
    /// and replacing it is the behaviour people resent most.
    private static let minimumLengthToCorrect = 3

    public init() {}

    // MARK: - Bar contents

    public func suggestions(forPartialWord word: String) -> SuggestionSet {
        guard !word.isEmpty else { return SuggestionSet(literal: "", candidates: []) }
        return SuggestionSet(literal: word, candidates: corrections(for: word))
    }

    // MARK: - Word-boundary replacement

    /// The replacement to apply when the word is finished, or nil to leave it alone.
    ///
    /// Deliberately more conservative than the bar: a suggestion the user can ignore
    /// costs nothing, while a silent replacement of something they meant is the worst
    /// failure this feature has.
    public func autoReplacement(for word: String) -> String? {
        guard !kept.contains(word.lowercased()),
              // Identifiers, codes and measurements are never typos.
              !word.contains(where: \.isNumber) else {
            return nil
        }
        // "i" alone is the first-person pronoun, and the one word the length floor
        // does not shield: unlike "hm" or "x", a lone lowercase "i" is a typo for
        // "I" nearly every time, and stock fixes it at every word ending. Keeping
        // the lowercase form still turns this off for good, like any rejection.
        if word == "i" { return "I" }
        guard word.count >= Self.minimumLengthToCorrect else { return nil }
        return corrections(for: word).first
    }

    /// The user chose their own spelling. Stop correcting it, this session and after —
    /// `ignoreWord` also keeps it out of the checker's own guesses.
    public func keepAsTyped(_ word: String) {
        let lowered = word.lowercased()
        kept.insert(lowered)
        checker.ignoreWord(word)
        checker.ignoreWord(lowered)
        guessCache[lowered] = []
    }

    // MARK: - Spoken feedback

    /// What VoiceOver speaks when a word is silently replaced at a boundary. A pure
    /// function so the wording is pinned by tests; the caller posts it, which is a
    /// no-op with VoiceOver off. The one edit the user cannot see coming must not
    /// also be one they cannot hear — stock speaks its autocorrections too.
    public static func announcement(replacing word: String, with replacement: String) -> String {
        "Corrected \(word) to \(replacement)"
    }

    // MARK: - Dictionary

    private func corrections(for word: String) -> [String] {
        let lowered = word.lowercased()
        guard !kept.contains(lowered) else { return [] }
        // The pronoun again (see autoReplacement): the length floor protects
        // deliberate short words, and this is the one short word that is not.
        if word == "i" { return ["I"] }
        guard word.count >= Self.minimumLengthToCorrect else { return [] }
        if let cached = guessCache[lowered] { return cached }

        let result: [String]
        if isKnown(word) {
            result = []
        } else {
            let range = NSRange(location: 0, length: word.utf16.count)
            let guesses = checker.guesses(forWordRange: range, in: word, language: "en_US") ?? []
            result = Array(
                guesses
                    .filter { $0.caseInsensitiveCompare(word) != .orderedSame }
                    .prefix(2)
            )
        }

        if guessCache.count >= Self.cacheLimit { guessCache.removeAll(keepingCapacity: true) }
        guessCache[lowered] = result
        return result
    }

    /// A word passes if either its lowercase *or* capitalised form is known, so proper
    /// nouns are not treated as mistakes — the same rule Rune Pad's checker uses.
    private func isKnown(_ word: String) -> Bool {
        !isUnknown(word) || !isUnknown(word.capitalized)
    }

    private func isUnknown(_ word: String) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        return checker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: "en_US"
        ).location != NSNotFound
    }
}
