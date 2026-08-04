import XCTest
@testable import SleepTokenKB

/// The keyboard had no correction of any kind: a letter went straight into the document
/// and the only word-boundary logic was the double-space period. Stock offers candidates
/// as you type and replaces a clearly-wrong word when you hit space.
///
/// The blue-underline-in-the-text-field affordance stock uses is first-party — a keyboard
/// extension can only read and write text, never style it — so this is the same thing
/// every third-party keyboard does instead: a bar of candidates over the keys.
final class SuggestionsTests: XCTestCase {

    // MARK: - Finding the word being typed

    func testCurrentWordIsTheRunSinceTheLastBoundary() {
        XCTAssertEqual(WordBoundary.currentWord(in: "hello wor"), "wor")
    }

    func testTrailingSpaceMeansNoWordInProgress() {
        XCTAssertEqual(WordBoundary.currentWord(in: "hello "), "")
    }

    func testEmptyContextHasNoWord() {
        XCTAssertEqual(WordBoundary.currentWord(in: ""), "")
    }

    func testPunctuationEndsAWord() {
        XCTAssertEqual(WordBoundary.currentWord(in: "wait. th"), "th")
        XCTAssertEqual(WordBoundary.currentWord(in: "one,two"), "two")
    }

    /// Newlines are boundaries too — a word does not continue across a return.
    func testNewlineEndsAWord() {
        XCTAssertEqual(WordBoundary.currentWord(in: "first\nsec"), "sec")
    }

    /// Apostrophes are part of the word, or "don" and "t" become separate words and
    /// every contraction gets flagged.
    func testApostropheStaysInsideTheWord() {
        XCTAssertEqual(WordBoundary.currentWord(in: "I don't"), "don't")
    }

    func testBoundaryCharactersAreRecognised() {
        for character in [" ", ".", ",", "!", "?", "\n", ";", ":"] {
            XCTAssertTrue(
                WordBoundary.isBoundary(Character(character)),
                "\(character) should end a word"
            )
        }
        for character in ["a", "Z", "'", "1"] {
            XCTAssertFalse(
                WordBoundary.isBoundary(Character(character)),
                "\(character) should not end a word"
            )
        }
    }

    // MARK: - Multi-scalar emoji

    /// Emoji are routinely more than one scalar, and neither VS16 nor a ZWJ belongs to
    /// a boundary category — so an every-scalar rule called "❤️" a word character and
    /// glued it to whatever followed. This keyboard ships both of these in its own
    /// emoji catalog.
    func testMultiScalarEmojiEndAWord() {
        for emoji in ["❤️", "😮‍💨", "🏳️‍🌈", "😀", "🇺🇸"] {
            XCTAssertTrue(
                WordBoundary.isBoundary(Character(emoji)),
                "\(emoji) should end a word"
            )
        }
    }

    func testAnEmojiDoesNotGlueToTheNextWord() {
        XCTAssertEqual(WordBoundary.currentWord(in: "hi ❤️hey"), "hey")
        XCTAssertEqual(WordBoundary.currentWord(in: "sent 😮‍💨"), "")
    }

    /// Combining marks are the case the ANY-scalar rule must not break: neither "e"
    /// nor U+0301 is a boundary on its own, so the composed character stays in-word.
    func testAccentedLettersStayInsideTheWord() {
        XCTAssertEqual(WordBoundary.currentWord(in: "caf\u{65}\u{301}"), "cafe\u{301}")
        XCTAssertFalse(WordBoundary.isBoundary("é"))
    }

    // MARK: - The caret inside a word

    /// "wor|lds": the fragment left of the caret is not a finished word, and
    /// correcting it would splice into the middle of one. Stock stands down.
    func testCaretIsInsideWordWhenALetterFollows() {
        XCTAssertTrue(WordBoundary.caretIsInsideWord(contextAfter: "lds and more"))
    }

    /// The end of the document is where the caret lives while typing; never mid-word.
    func testCaretIsNotInsideWordAtEndOfDocument() {
        XCTAssertFalse(WordBoundary.caretIsInsideWord(contextAfter: nil))
        XCTAssertFalse(WordBoundary.caretIsInsideWord(contextAfter: ""))
    }

    func testCaretIsNotInsideWordWhenABoundaryFollows() {
        XCTAssertFalse(WordBoundary.caretIsInsideWord(contextAfter: " world"))
        XCTAssertFalse(WordBoundary.caretIsInsideWord(contextAfter: ". Next"))
        XCTAssertFalse(WordBoundary.caretIsInsideWord(contextAfter: "\nnew line"))
    }

    /// The apostrophe is in-word, so "don|'t" counts as inside — replacing "don"
    /// there would maim the contraction.
    func testCaretBeforeAnApostropheIsInsideTheWord() {
        XCTAssertTrue(WordBoundary.caretIsInsideWord(contextAfter: "'t"))
    }

    // MARK: - Candidates

    /// Stock always keeps what you actually typed available as the first option, so a
    /// correction can never be forced on you. That slot is the whole safety valve.
    func testLiteralIsAlwaysTheFirstSlot() {
        let engine = SuggestionEngine()
        let set = engine.suggestions(forPartialWord: "teh")
        XCTAssertEqual(set.literal, "teh")
    }

    func testMisspellingProducesCandidates() {
        let engine = SuggestionEngine()
        let set = engine.suggestions(forPartialWord: "teh")
        XCTAssertFalse(set.candidates.isEmpty, "expected a correction for 'teh'")
        XCTAssertTrue(
            set.candidates.contains("the"),
            "expected 'the' among \(set.candidates)"
        )
    }

    func testCorrectlySpelledWordOffersNoCorrection() {
        let engine = SuggestionEngine()
        XCTAssertTrue(engine.suggestions(forPartialWord: "keyboard").candidates.isEmpty)
    }

    func testNoWordMeansNoSuggestions() {
        let engine = SuggestionEngine()
        XCTAssertTrue(engine.suggestions(forPartialWord: "").isEmpty)
    }

    /// A single letter is not a typo worth correcting; stock leaves it alone.
    func testSingleCharactersAreLeftAlone() {
        let engine = SuggestionEngine()
        XCTAssertTrue(engine.suggestions(forPartialWord: "a").candidates.isEmpty)
    }

    /// The bar has three slots and one is the literal.
    func testCandidatesAreCapped() {
        let engine = SuggestionEngine()
        XCTAssertLessThanOrEqual(engine.suggestions(forPartialWord: "teh").candidates.count, 2)
    }

    // MARK: - Auto-replacement on a word boundary

    func testClearMisspellingIsAutoReplaced() {
        let engine = SuggestionEngine()
        XCTAssertEqual(engine.autoReplacement(for: "teh"), "the")
    }

    func testKnownWordIsNeverAutoReplaced() {
        let engine = SuggestionEngine()
        XCTAssertNil(engine.autoReplacement(for: "keyboard"))
        XCTAssertNil(engine.autoReplacement(for: "ritual"))
    }

    /// Short strings are usually deliberate (initials, "ok", "hm"), and replacing them
    /// is the behaviour people hate most.
    func testVeryShortWordsAreNeverAutoReplaced() {
        let engine = SuggestionEngine()
        XCTAssertNil(engine.autoReplacement(for: "hm"))
        XCTAssertNil(engine.autoReplacement(for: "x"))
    }

    /// Anything with a digit is an identifier, a code, or a measurement.
    func testWordsContainingDigitsAreNeverAutoReplaced() {
        let engine = SuggestionEngine()
        XCTAssertNil(engine.autoReplacement(for: "abc123"))
    }

    // MARK: - The first-person pronoun

    /// The one exception to the length floor: a lone lowercase "i" is the pronoun
    /// nearly every time, and stock capitalizes it at every word ending.
    func testLoneLowercaseIIsCapitalized() {
        let engine = SuggestionEngine()
        XCTAssertEqual(engine.autoReplacement(for: "i"), "I")
    }

    /// The bar offers it too, so the fix is visible before the boundary applies it.
    func testThePronounIsOfferedInTheBar() {
        let engine = SuggestionEngine()
        XCTAssertEqual(engine.suggestions(forPartialWord: "i").candidates, ["I"])
    }

    /// Already capitalized means nothing to fix.
    func testUppercaseIIsLeftAlone() {
        let engine = SuggestionEngine()
        XCTAssertNil(engine.autoReplacement(for: "I"))
    }

    /// Keeping the lowercase form wins, like any other rejection: someone who
    /// writes "i" on purpose gets to.
    func testKeepingLowercaseIDisablesThePronounRule() {
        let engine = SuggestionEngine()
        engine.keepAsTyped("i")
        XCTAssertNil(engine.autoReplacement(for: "i"))
        XCTAssertTrue(engine.suggestions(forPartialWord: "i").candidates.isEmpty)
    }

    // MARK: - Spoken feedback

    /// The wording VoiceOver speaks when a word is silently replaced. Pinned here
    /// because the view can only post it, never test it.
    func testAnnouncementNamesBothWords() {
        XCTAssertEqual(
            SuggestionEngine.announcement(replacing: "teh", with: "the"),
            "Corrected teh to the"
        )
    }

    // MARK: - Learning

    /// Rejecting a correction has to stick, or the keyboard argues with the user
    /// every single time they type their own vocabulary.
    func testRejectedWordStopsBeingCorrected() {
        let engine = SuggestionEngine()
        let word = "vessel"
        // Whether the dictionary knows it or not, after rejection it must be left alone.
        engine.keepAsTyped(word)
        XCTAssertNil(engine.autoReplacement(for: word))
        XCTAssertTrue(engine.suggestions(forPartialWord: word).candidates.isEmpty)
    }

    func testLearningOneWordDoesNotDisableEverythingElse() {
        let engine = SuggestionEngine()
        engine.keepAsTyped("vessel")
        XCTAssertEqual(engine.autoReplacement(for: "teh"), "the")
    }

    // MARK: - Case-sensitive memoisation

    /// The cache is keyed by the exact word because `guesses` preserves the query's
    /// case. Sharing a lowercased key let whichever casing was computed first win the
    /// session: a sentence-start "Teh" cached as "The" then silently capitalised a
    /// mid-sentence "teh" — a wrong capital applied without review.
    func testCorrectionsKeepTheCaseOfTheWordAsked() {
        let engine = SuggestionEngine()
        XCTAssertEqual(engine.autoReplacement(for: "Teh"), "The")
        XCTAssertEqual(
            engine.autoReplacement(for: "teh"), "the",
            "a lowercase typo must not inherit the capitalised form's correction"
        )
    }

    func testTheReverseOrderIsAlsoStable() {
        let engine = SuggestionEngine()
        XCTAssertEqual(engine.autoReplacement(for: "teh"), "the")
        XCTAssertEqual(engine.autoReplacement(for: "Teh"), "The")
    }

    // MARK: - The synchronous fast path

    /// What the engine can answer without the dictionary, so the typing path never
    /// waits on `SpellWorker` for these.
    func testFreeAnswersNeedNoDictionary() {
        let engine = SuggestionEngine()
        XCTAssertEqual(engine.immediateSuggestions(forPartialWord: "")?.candidates, [])
        XCTAssertEqual(engine.immediateSuggestions(forPartialWord: "hm")?.candidates, [])
        XCTAssertEqual(engine.immediateSuggestions(forPartialWord: "i")?.candidates, ["I"])

        engine.keepAsTyped("vessel")
        XCTAssertEqual(engine.immediateSuggestions(forPartialWord: "vessel")?.candidates, [])
    }

    /// A word needing real guesses reports "not yet" rather than paying for them.
    func testAWordNeedingTheDictionaryHasNoImmediateAnswer() {
        let engine = SuggestionEngine()
        XCTAssertNil(engine.immediateSuggestions(forPartialWord: "teh"))
    }

    /// Once a background result is filed, the next keystroke gets it for free.
    func testRememberedResultsBecomeImmediate() {
        let engine = SuggestionEngine()
        engine.remember("teh", corrections: ["the", "ten"])
        XCTAssertEqual(
            engine.immediateSuggestions(forPartialWord: "teh")?.candidates,
            ["the", "ten"]
        )
    }

    /// Keeping a word must invalidate what was already memoised for it, in any casing,
    /// or the bar keeps offering the correction the user just rejected.
    func testKeepingAWordClearsItsMemo() {
        let engine = SuggestionEngine()
        engine.remember("Teh", corrections: ["The"])
        engine.keepAsTyped("teh")
        XCTAssertEqual(engine.immediateSuggestions(forPartialWord: "Teh")?.candidates, [])
        XCTAssertEqual(engine.immediateSuggestions(forPartialWord: "teh")?.candidates, [])
    }

    // MARK: - The background speller

    /// The two checkers must answer the same question the same way — the sync engine
    /// serves boundary replacement, the actor serves the bar, and a disagreement would
    /// mean the bar offers one word while space commits another.
    func testTheWorkerAgreesWithTheSynchronousEngine() async {
        let engine = SuggestionEngine()
        for word in ["teh", "recieve", "keyboard", "ritual"] {
            let fromWorker = await SpellWorker.shared.corrections(for: word)
            let fromEngine = engine.suggestions(forPartialWord: word).candidates
            XCTAssertEqual(fromWorker, fromEngine, "the two checkers disagree about \(word)")
        }
    }
}

/// The bar's geometry is fixed per origin, not per candidate count.
final class SuggestionOriginTests: XCTestCase {

    /// Three columns for spelling (the literal plus two guesses), four for a glide
    /// round (the committed word plus three alternates) — the counts the engine and
    /// decoder actually produce.
    func testSlotCountsMatchWhatEachSourceProduces() {
        XCTAssertEqual(SuggestionOrigin.spelling.slotCount, 3)
        XCTAssertEqual(SuggestionOrigin.glide.slotCount, 4)
    }

    /// A set never carries more candidates than its origin reserves room for.
    func testEngineCandidatesFitTheSpellingSlots() {
        let engine = SuggestionEngine()
        let set = engine.suggestions(forPartialWord: "teh")
        XCTAssertLessThanOrEqual(set.candidates.count, SuggestionOrigin.spelling.slotCount - 1)
    }

    func testSpellingIsTheDefaultOrigin() {
        XCTAssertEqual(SuggestionSet(literal: "a", candidates: []).origin, .spelling)
    }
}

/// Only the newest request may publish: `SpellWorker` results arrive out of order
/// whenever a long word's guesses outlast a short one's.
final class SuggestionRequestTests: XCTestCase {

    func testOnlyTheNewestTokenIsCurrent() {
        let request = SuggestionRequest()
        let first = request.issue()
        let second = request.issue()
        XCTAssertFalse(request.isCurrent(first), "a superseded request must not publish")
        XCTAssertTrue(request.isCurrent(second))
    }

    func testCancelAllAbandonsEveryRequestInFlight() {
        let request = SuggestionRequest()
        let token = request.issue()
        request.cancelAll()
        XCTAssertFalse(request.isCurrent(token))
    }
}
