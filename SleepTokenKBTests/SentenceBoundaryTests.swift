import XCTest
@testable import SleepTokenKB

/// Closing punctuation is the one vocabulary two rules share: autocapitalisation looks
/// past it to find the terminator, and the double-space period looks past it to find
/// the word it ends. They used to keep separate lists — one of them empty — so
/// `(see above)` plus two quick spaces armed shift but refused the period.
final class SentenceBoundaryTests: XCTestCase {

    func testClosersAreTheBracketsAndQuotesThatCanFollowAWord() {
        XCTAssertEqual(
            SentenceBoundary.closers,
            ["\"", "'", ")", "]", "}", "\u{201D}", "\u{2019}"]
        )
    }

    func testTerminatorsEndASentence() {
        XCTAssertEqual(SentenceBoundary.terminators, [".", "!", "?"])
    }

    /// Both rules read the one set, so a closer added for one cannot be missed by the other.
    func testBothRulesAgreeOnEveryCloser() {
        for closer in SentenceBoundary.closers {
            XCTAssertTrue(
                PeriodShortcut.shouldSubstitute(contextBefore: "done\(closer) ", sinceLastSpace: 0.2),
                "the period shortcut must look past \(closer.debugDescription)"
            )
            XCTAssertEqual(
                Autocapitalization.nextShift(
                    for: .sentences, contextBefore: "Done.\(closer) ", current: .off, autoArmed: false
                ),
                .shifted,
                "autocapitalisation must look past \(closer.debugDescription)"
            )
        }
    }
}
