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
}
