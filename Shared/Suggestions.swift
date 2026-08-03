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

    /// ANY boundary scalar ends the word, not every scalar.
    ///
    /// Emoji are routinely multi-scalar: "❤️" is So + VS16, "😮‍💨" carries a ZWJ, and
    /// neither VS16 (Mn) nor ZWJ (Cf) belongs to a boundary category — so an
    /// every-scalar rule declared them word characters and glued them to whatever
    /// followed. Combining marks stay in-word under this rule, because neither "e"
    /// nor U+0301 is a boundary on its own.
    public static func isBoundary(_ character: Character) -> Bool {
        character.unicodeScalars.contains { boundaries.contains($0) }
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

/// What produced the bar's contents, which is also what fixes its geometry.
public enum SuggestionOrigin: Equatable, Sendable {
    /// Spell candidates for the word being typed.
    case spelling
    /// A finished glide's alternates.
    case glide

    /// Columns the bar lays out, whatever it currently has to show.
    ///
    /// Fixed per origin on purpose: dividing the bar by however many candidates
    /// happen to exist made every slot edge slide horizontally as `UITextChecker`
    /// results came and went, moving tap targets mid-word. Stock's slots never move.
    public var slotCount: Int {
        switch self {
        case .spelling: 3   // the literal plus up to two guesses
        case .glide: 4      // the committed word plus up to three alternates
        }
    }
}

/// Candidates for the bar above the keys.
public struct SuggestionSet: Equatable {
    /// What the user actually typed. Stock always keeps this available so a correction
    /// can never be forced; it is the whole safety valve.
    public let literal: String
    /// Best first. Spell suggestions offer up to two corrections; a glide's
    /// alternates offer up to three. The bar reserves `origin.slotCount` columns
    /// regardless and leaves the unfilled ones blank.
    public let candidates: [String]
    public let origin: SuggestionOrigin

    public var isEmpty: Bool { literal.isEmpty && candidates.isEmpty }

    public init(literal: String, candidates: [String], origin: SuggestionOrigin = .spelling) {
        self.literal = literal
        self.candidates = candidates
        self.origin = origin
    }
}

/// The `UITextChecker` work itself, in one place so the synchronous and background
/// paths cannot answer the same word differently.
enum SpellCheck {
    /// Below this length a "misspelling" is usually deliberate — initials, "ok", "hm" —
    /// and replacing it is the behaviour people resent most.
    static let minimumLengthToCorrect = 3

    /// The one short word that is not deliberate: a lone lowercase "i" is the
    /// first-person pronoun nearly every time, and stock capitalises it at every
    /// word ending.
    static let pronounCorrection = "I"

    static func isPronoun(_ word: String) -> Bool { word == "i" }

    /// Up to two guesses for a word already known to be worth checking — the caller
    /// has cleared the kept-word and length gates.
    static func corrections(for word: String, using checker: UITextChecker) -> [String] {
        if isKnown(word, using: checker) { return [] }
        let range = NSRange(location: 0, length: word.utf16.count)
        let guesses = checker.guesses(forWordRange: range, in: word, language: "en_US") ?? []
        return Array(
            guesses
                .filter { $0.caseInsensitiveCompare(word) != .orderedSame }
                .prefix(2)
        )
    }

    /// A word passes if either its lowercase *or* capitalised form is known, so proper
    /// nouns are not treated as mistakes — the same rule Rune Pad's checker uses.
    private static func isKnown(_ word: String, using checker: UITextChecker) -> Bool {
        !isUnknown(word, using: checker) || !isUnknown(word.capitalized, using: checker)
    }

    private static func isUnknown(_ word: String, using checker: UITextChecker) -> Bool {
        let range = NSRange(location: 0, length: word.utf16.count)
        return checker.rangeOfMisspelledWord(
            in: word, range: range, startingAt: 0, wrap: false, language: "en_US"
        ).location != NSNotFound
    }
}

/// The background speller for the candidate bar.
///
/// `guesses(forWordRange:)` costs single-digit to tens of milliseconds and every
/// keystroke asks about a new prefix, so running it inline put that on the main actor
/// inside the SwiftUI update, next to the controller's per-keystroke root rebuild. The
/// actor owns its own `UITextChecker` — instances are independent, and actor isolation
/// is what serialises access to a type that is not `Sendable`.
///
/// Only the BAR is served from here. Boundary replacement stays synchronous on
/// `SuggestionEngine`, because it has to finish before the space it precedes lands.
public actor SpellWorker {
    public static let shared = SpellWorker()

    private let checker = UITextChecker()

    public init() {}

    public func corrections(for word: String) -> [String] {
        SpellCheck.corrections(for: word, using: checker)
    }

    /// Mirrors `SuggestionEngine.keepAsTyped` so the two checkers hold the same
    /// vocabulary. The kept-word gate itself lives on the engine and runs before
    /// anything reaches this actor; this only keeps the guesses in step.
    public func keep(_ word: String) {
        checker.ignoreWord(word)
        checker.ignoreWord(word.lowercased())
    }
}

/// Which candidate request is current.
///
/// A reference type held in `@State` for the same reason `SpaceTracker` is: nothing
/// renders it, so issuing a token must not invalidate the view tree — and the instance
/// has to survive the controller's per-keystroke `rootView` reassignments. Results from
/// `SpellWorker` arrive out of order whenever a long word's guesses outlast a short
/// one's; only the newest token may publish.
final class SuggestionRequest {
    private var current = 0

    /// Issues the token for a request about to be made.
    func issue() -> Int {
        current += 1
        return current
    }

    func isCurrent(_ token: Int) -> Bool { token == current }

    /// Abandons every request in flight, so a stale answer cannot land after the
    /// field changed or correction was switched off.
    func cancelAll() {
        current += 1
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
    /// Serves the synchronous boundary path only. `lazy` because the bar's background
    /// worker usually fills the memo first, in which case this second checker is never
    /// constructed at all.
    private lazy var checker = UITextChecker()

    /// Keyed by the EXACT word, not its lowercase form: `guesses` preserves the query's
    /// case, so a shared key let whichever casing was computed first win the session —
    /// a cached sentence-start "Teh" then silently replaced a mid-sentence "teh" with
    /// a capitalised "The".
    private var guessCache: [String: [String]] = [:]
    private static let cacheLimit = 512

    /// Words the user explicitly kept. Rejecting a correction has to stick, or the
    /// keyboard argues with them about their own vocabulary forever.
    private var kept: Set<String> = []

    public init() {}

    // MARK: - Bar contents

    /// The complete answer, computing whatever is missing.
    public func suggestions(forPartialWord word: String) -> SuggestionSet {
        guard !word.isEmpty else { return SuggestionSet(literal: "", candidates: []) }
        return SuggestionSet(literal: word, candidates: corrections(for: word))
    }

    /// The answer when it costs nothing — an empty word, a kept word, a word under the
    /// length floor, the pronoun, or a memo already filled. `nil` means the dictionary
    /// has to be consulted, which the caller should do off the main actor via
    /// `SpellWorker` and then hand back through `remember`.
    public func immediateSuggestions(forPartialWord word: String) -> SuggestionSet? {
        guard !word.isEmpty else { return SuggestionSet(literal: "", candidates: []) }
        if let known = shortCircuit(for: word) {
            return SuggestionSet(literal: word, candidates: known)
        }
        if let cached = guessCache[word] {
            return SuggestionSet(literal: word, candidates: cached)
        }
        return nil
    }

    /// Files a background result under the exact word it was computed for.
    public func remember(_ word: String, corrections: [String]) {
        guard shortCircuit(for: word) == nil else { return }
        evictIfFull(keepingPrefixesOf: word)
        guessCache[word] = corrections
    }

    // MARK: - Word-boundary replacement

    /// The replacement to apply when the word is finished, or nil to leave it alone.
    ///
    /// Deliberately more conservative than the bar: a suggestion the user can ignore
    /// costs nothing, while a silent replacement of something they meant is the worst
    /// failure this feature has. Synchronous by requirement — it runs before the space
    /// or punctuation that ends the word, so it cannot wait on an actor hop.
    public func autoReplacement(for word: String) -> String? {
        guard !kept.contains(word.lowercased()),
              // Identifiers, codes and measurements are never typos.
              !word.contains(where: \.isNumber) else {
            return nil
        }
        return corrections(for: word).first
    }

    /// The user chose their own spelling. Stop correcting it, this session and after —
    /// `ignoreWord` also keeps it out of the checker's own guesses.
    public func keepAsTyped(_ word: String) {
        let lowered = word.lowercased()
        kept.insert(lowered)
        checker.ignoreWord(word)
        checker.ignoreWord(lowered)
        // Anything already memoised for this word, in any casing, is now wrong.
        guessCache = guessCache.filter { $0.key.lowercased() != lowered }
    }

    // MARK: - Spoken feedback

    /// What VoiceOver speaks when a word is silently replaced. A pure function so the
    /// wording is pinned by tests; the caller posts it, which is a no-op with VoiceOver
    /// off. The one edit the user cannot see coming must not also be one they cannot
    /// hear — stock speaks its autocorrections too.
    public static func announcement(replacing word: String, with replacement: String) -> String {
        "Corrected \(word) to \(replacement)"
    }

    // MARK: - Dictionary

    private func corrections(for word: String) -> [String] {
        if let known = shortCircuit(for: word) { return known }
        if let cached = guessCache[word] { return cached }

        let result = SpellCheck.corrections(for: word, using: checker)
        evictIfFull(keepingPrefixesOf: word)
        guessCache[word] = result
        return result
    }

    /// Every answer reachable without the dictionary. `nil` means "ask the checker".
    private func shortCircuit(for word: String) -> [String]? {
        if kept.contains(word.lowercased()) { return [] }
        if SpellCheck.isPronoun(word) { return [SpellCheck.pronounCorrection] }
        if word.count < SpellCheck.minimumLengthToCorrect { return [] }
        return nil
    }

    /// Drops everything except the in-progress word's own prefixes. Wiping the lot
    /// discarded the memos the very next keystroke needs, so the eviction always
    /// landed as a stall mid-word.
    private func evictIfFull(keepingPrefixesOf word: String) {
        guard guessCache.count >= Self.cacheLimit else { return }
        guessCache = guessCache.filter { word.hasPrefix($0.key) }
    }
}
