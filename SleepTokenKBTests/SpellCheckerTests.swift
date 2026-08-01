import XCTest
@testable import SleepTokenKB

/// Rune Pad's spell check previously lived inline in a computed property reached from
/// `body`: a fresh `UITextChecker` was allocated and every completed word re-checked on
/// each keystroke. Pulling it into a type makes the two rules that actually matter
/// testable — which words count as finished, and which finished words get flagged.
final class SpellCheckerTests: XCTestCase {

    // MARK: - Which words are eligible to be judged

    /// The word still being typed must not be judged, or it flickers amber mid-word.
    func testTrailingWordIsExcludedWhileStillBeingTyped() {
        let words = ["sleep", "toke"]
        XCTAssertEqual(
            SpellChecker.completedWords(words, textEndsWithSpace: false),
            ["sleep"]
        )
    }

    /// A trailing space is what finishes a column, so every word becomes eligible.
    func testTrailingSpaceCompletesEveryWord() {
        let words = ["sleep", "token"]
        XCTAssertEqual(
            SpellChecker.completedWords(words, textEndsWithSpace: true),
            ["sleep", "token"]
        )
    }

    func testSingleUnfinishedWordLeavesNothingToJudge() {
        XCTAssertEqual(SpellChecker.completedWords(["wors"], textEndsWithSpace: false), [])
    }

    func testEmptyInputStaysEmpty() {
        XCTAssertEqual(SpellChecker.completedWords([], textEndsWithSpace: false), [])
        XCTAssertEqual(SpellChecker.completedWords([], textEndsWithSpace: true), [])
    }

    // MARK: - Which completed words get flagged

    func testKnownWordIsNotFlagged() {
        let checker = SpellChecker()
        XCTAssertTrue(checker.misspelled(in: ["worship"]).isEmpty)
    }

    func testUnknownWordIsFlagged() {
        let checker = SpellChecker()
        XCTAssertEqual(checker.misspelled(in: ["zxqwvk"]), ["zxqwvk"])
    }

    /// A word passes if either its lowercase or capitalized form is known, so the
    /// band's proper nouns are not treated as mistakes.
    func testProperNounsPassViaCapitalizedForm() {
        let checker = SpellChecker()
        XCTAssertTrue(checker.misspelled(in: ["euclid"]).isEmpty)
        XCTAssertTrue(checker.misspelled(in: ["arcadia"]).isEmpty)
    }

    /// Single letters are legitimate columns and were never judged.
    func testSingleCharacterWordsAreNeverFlagged() {
        let checker = SpellChecker()
        XCTAssertTrue(checker.misspelled(in: ["a", "z"]).isEmpty)
    }

    func testFlagsOnlyTheUnknownWordsInAMixedSet() {
        let checker = SpellChecker()
        XCTAssertEqual(checker.misspelled(in: ["worship", "zxqwvk", "token"]), ["zxqwvk"])
    }

    // MARK: - Memoization must not change answers

    /// The whole point of the change is reusing one checker across keystrokes. If the
    /// cache ever disagreed with a fresh lookup, the optimization would be a bug.
    func testRepeatedLookupsAgreeWithTheFirstAnswer() {
        let checker = SpellChecker()
        let words = ["worship", "zxqwvk", "euclid", "a"]
        let first = checker.misspelled(in: words)
        for _ in 0..<5 {
            XCTAssertEqual(checker.misspelled(in: words), first)
        }
        XCTAssertEqual(first, ["zxqwvk"])
    }

    /// A cached instance must give the same verdict a brand-new one would.
    func testCachedInstanceAgreesWithAFreshInstance() {
        let warmed = SpellChecker()
        let words = ["token", "zxqwvk", "arcadia"]
        _ = warmed.misspelled(in: words)
        XCTAssertEqual(warmed.misspelled(in: words), SpellChecker().misspelled(in: words))
    }
}
