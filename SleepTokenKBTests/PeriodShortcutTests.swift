import XCTest
@testable import SleepTokenKB

/// Double-space-for-period is iOS muscle memory, and each guard exists because dropping it
/// produces visible damage: ".." after a sentence, a period after a bare space, or a
/// period appearing when the user simply paused between two words.
final class PeriodShortcutTests: XCTestCase {

    func testTwoQuickSpacesAfterAWordSubstituteAPeriod() {
        XCTAssertTrue(PeriodShortcut.shouldSubstitute(contextBefore: "hello ", sinceLastSpace: 0.2))
    }

    /// Two spaces typed a minute apart are two deliberate spaces, not a sentence end.
    func testASlowSecondSpaceIsJustASpace() {
        XCTAssertFalse(PeriodShortcut.shouldSubstitute(contextBefore: "hello ", sinceLastSpace: 5))
    }

    func testAThirdSpaceDoesNotSubstituteAgain() {
        XCTAssertFalse(PeriodShortcut.shouldSubstitute(contextBefore: "hello  ", sinceLastSpace: 0.2))
    }

    /// Guards against ".. " and "!. ".
    func testNoSubstitutionAfterExistingPunctuation() {
        for mark in [".", "!", "?", ","] {
            XCTAssertFalse(
                PeriodShortcut.shouldSubstitute(contextBefore: "hello\(mark) ", sinceLastSpace: 0.2),
                "should not add a period after \(mark)"
            )
        }
    }

    func testNoSubstitutionAtTheStartOfAField() {
        XCTAssertFalse(PeriodShortcut.shouldSubstitute(contextBefore: nil, sinceLastSpace: 0.2))
        XCTAssertFalse(PeriodShortcut.shouldSubstitute(contextBefore: "", sinceLastSpace: 0.2))
        XCTAssertFalse(PeriodShortcut.shouldSubstitute(contextBefore: " ", sinceLastSpace: 0.2))
    }

    func testDigitsCountAsWordCharacters() {
        XCTAssertTrue(PeriodShortcut.shouldSubstitute(contextBefore: "42 ", sinceLastSpace: 0.2))
    }

    /// The shortcut fires on the *second* space; if the last character is not a space there
    /// is no first space to replace.
    func testNoSubstitutionWhenTheLastCharacterIsNotASpace() {
        XCTAssertFalse(PeriodShortcut.shouldSubstitute(contextBefore: "hello", sinceLastSpace: 0.2))
    }

    func testNoSubstitutionAfterANewline() {
        XCTAssertFalse(PeriodShortcut.shouldSubstitute(contextBefore: "hello\n", sinceLastSpace: 0.2))
    }

    /// An expired window must short-circuit before the host document is read at all:
    /// the context arrives as an autoclosure precisely so the common case (a space that
    /// is not part of a double-tap) costs nothing.
    func testTheContextIsNotReadWhenTheWindowAlreadyExpired() {
        var reads = 0
        _ = PeriodShortcut.shouldSubstitute(
            contextBefore: { reads += 1; return "hello " }(),
            sinceLastSpace: 5
        )
        XCTAssertEqual(reads, 0, "an expired window must not read the document")

        _ = PeriodShortcut.shouldSubstitute(
            contextBefore: { reads += 1; return "hello " }(),
            sinceLastSpace: 0.2
        )
        XCTAssertEqual(reads, 1, "a live window reads the document exactly once")
    }

    /// The boundary itself, so the window cannot be quietly narrowed to nothing.
    func testTheWindowIsInclusiveAtItsEdge() {
        XCTAssertTrue(
            PeriodShortcut.shouldSubstitute(contextBefore: "hello ", sinceLastSpace: PeriodShortcut.window)
        )
        XCTAssertFalse(
            PeriodShortcut.shouldSubstitute(contextBefore: "hello ", sinceLastSpace: PeriodShortcut.window + 0.01)
        )
    }
}
