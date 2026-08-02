import XCTest
@testable import SleepTokenKB

/// Stock iOS returns to the letters page on the first space after a digit or a mark, which
/// is why "hello?" then space then a word takes one tap on 123 rather than two. Ours stayed
/// on symbols, so every sentence that ended in punctuation charged a tap on ABC to get back
/// to writing.
///
/// The cases below are the system keyboard's own answers, measured on iOS 26 by driving the
/// real thing rather than reasoning about it. The subtle half is what *arms* the return: the
/// first keystroke of a visit, not arrival on the page.
final class PageAfterSpaceTests: XCTestCase {

    private func page(
        from current: KeyboardMetrics.Page,
        typedSinceEntering: Bool,
        numberPadField: Bool = false
    ) -> KeyboardMetrics.Page {
        PageAfterSpace.page(
            from: current,
            typedSinceEntering: typedSinceEntering,
            numberPadField: numberPadField
        )
    }

    // MARK: - Armed: a character was typed on this visit

    /// The reported case: "?", ".", "!" all live on the 123 page, and the space after them
    /// is the one that ends the sentence.
    func testSpaceAfterTypingOnTheNumbersPageReturnsToLetters() {
        XCTAssertEqual(page(from: .symbols, typedSinceEntering: true), .letters)
    }

    /// `. , ? ! '` are repeated on #+= precisely so punctuation is always one tap away; the
    /// space after them has to behave identically or the parity is cosmetic.
    func testSpaceAfterTypingOnTheSymbolsPageReturnsToLetters() {
        XCTAssertEqual(page(from: .symbolsAlt, typedSinceEntering: true), .letters)
    }

    // MARK: - Disarmed: nothing typed yet on this visit

    /// Measured: `123 space` stays on 123. This is the "meet me at " before the "5:30" —
    /// stock keeps the digits one tap away rather than charging a second tap on 123.
    func testABareSpaceOnTheNumbersPageStaysPut() {
        XCTAssertEqual(page(from: .symbols, typedSinceEntering: false), .symbols)
    }

    /// Measured: stock keeps #+= on a bare space too.
    func testABareSpaceOnTheSymbolsPageStaysPut() {
        XCTAssertEqual(page(from: .symbolsAlt, typedSinceEntering: false), .symbolsAlt)
    }

    // MARK: - Pages the rule never moves

    func testSpaceOnTheLettersPageChangesNothing() {
        for typed in [false, true] {
            XCTAssertEqual(page(from: .letters, typedSinceEntering: typed), .letters)
        }
    }

    /// Emoji is a destination, not a detour: stock's emoji keyboard keeps its grid across a
    /// space and leaves only on the explicit ABC key.
    func testSpaceOnTheEmojiPageStaysOnEmoji() {
        for typed in [false, true] {
            XCTAssertEqual(page(from: .emoji, typedSinceEntering: typed), .emoji)
        }
    }

    // MARK: - Number pad fields

    /// A custom keyboard replaces every keyboard type, so a phone or amount field gets these
    /// same pages. Snapping to letters there would take the user off the only page the field
    /// can use, on the keystroke they are most likely to repeat.
    func testANumberPadFieldKeepsWhicheverPageIsShowing() {
        for current in KeyboardMetrics.Page.allCases {
            for typed in [false, true] {
                XCTAssertEqual(
                    page(from: current, typedSinceEntering: typed, numberPadField: true),
                    current,
                    "\(current) (typed=\(typed)) must survive a space in a number pad field"
                )
            }
        }
    }

    // MARK: - Shape of the rule

    /// The space bar can only ever send you to letters or leave you where you are. It must
    /// never route to a page the user did not ask for — the failure that would make the
    /// space bar feel possessed rather than helpful.
    func testTheRuleOnlyEverReturnsLettersOrTheCurrentPage() {
        for current in KeyboardMetrics.Page.allCases {
            for typed in [false, true] {
                for numberPad in [false, true] {
                    let next = page(
                        from: current, typedSinceEntering: typed, numberPadField: numberPad
                    )
                    XCTAssertTrue(
                        next == .letters || next == current,
                        "\(current) (typed=\(typed), numberPad=\(numberPad)) routed to \(next)"
                    )
                }
            }
        }
    }

    /// Arming is the only thing that can move the page, so a disarmed space is inert
    /// everywhere. Two spaces in a row are the double-space shortcut's territory, and it
    /// must not find the page shifting under it.
    func testADisarmedSpaceMovesNothingAnywhere() {
        for current in KeyboardMetrics.Page.allCases {
            XCTAssertEqual(page(from: current, typedSinceEntering: false), current)
        }
    }

    /// The caller clears the arming when it applies the result, so the second space of a
    /// double tap arrives disarmed. Both orderings have to be inert to be safe.
    func testASecondSpaceMovesNothing() {
        for current in KeyboardMetrics.Page.allCases {
            let once = page(from: current, typedSinceEntering: true)
            XCTAssertEqual(
                page(from: once, typedSinceEntering: false), once,
                "space is not idempotent from \(current)"
            )
        }
    }
}
