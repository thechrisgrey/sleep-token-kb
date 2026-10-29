import XCTest
@testable import SleepTokenKB

/// After a silent replacement, stock offers the word you actually typed in the bar
/// the moment you backspace into the corrected one. Ours recorded nothing: "teh" became
/// "the" and the only road back was three backspaces, a retype, and "Keep teh".
final class CorrectionUndoTests: XCTestCase {

    func testTheTypedWordIsOfferedWhileTheCaretSitsOnItsReplacement() {
        var undo = CorrectionUndo()
        undo.record(typed: "teh", replacement: "the")
        XCTAssertEqual(undo.original(ifCurrentWordIs: "the"), "teh")
    }

    /// The memo answers only for the exact replacement: once the user types on, the
    /// word is theirs again and nothing is offered.
    func testNothingIsOfferedForAnyOtherWord() {
        var undo = CorrectionUndo()
        undo.record(typed: "teh", replacement: "the")
        XCTAssertNil(undo.original(ifCurrentWordIs: "ther"))
        XCTAssertNil(undo.original(ifCurrentWordIs: "th"))
        XCTAssertNil(undo.original(ifCurrentWordIs: ""))
    }

    func testAFreshMemoHasNothingToOffer() {
        XCTAssertNil(CorrectionUndo().original(ifCurrentWordIs: "the"))
    }

    /// Extending the word, switching fields, or reverting all end the offer.
    func testInterruptForgetsTheReplacement() {
        var undo = CorrectionUndo()
        undo.record(typed: "teh", replacement: "the")
        undo.interrupt()
        XCTAssertNil(undo.original(ifCurrentWordIs: "the"))
    }

    /// Only the most recent replacement can be undone — one slot, like stock.
    func testANewReplacementSupersedesTheLast() {
        var undo = CorrectionUndo()
        undo.record(typed: "teh", replacement: "the")
        undo.record(typed: "recieve", replacement: "receive")
        XCTAssertNil(undo.original(ifCurrentWordIs: "the"))
        XCTAssertEqual(undo.original(ifCurrentWordIs: "receive"), "recieve")
    }

    /// Case travels with the word: a sentence-start "Teh" came back as "The", and the
    /// offer must be the capital the user typed, not a lowercased ghost.
    func testTheOfferKeepsTheTypedCase() {
        var undo = CorrectionUndo()
        undo.record(typed: "Teh", replacement: "The")
        XCTAssertEqual(undo.original(ifCurrentWordIs: "The"), "Teh")
        XCTAssertNil(undo.original(ifCurrentWordIs: "the"))
    }
}
