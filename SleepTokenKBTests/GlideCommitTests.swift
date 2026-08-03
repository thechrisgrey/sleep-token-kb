import XCTest
@testable import SleepTokenKB

final class GlideCommitTests: XCTestCase {

    // MARK: - Casing

    func testShiftStatesCaseTheWord() {
        XCTAssertEqual(GlideCommit.insertion(word: "hello", shift: .off,
                                             contextBefore: nil, lastInsertWasGlide: false).word, "hello")
        XCTAssertEqual(GlideCommit.insertion(word: "hello", shift: .shifted,
                                             contextBefore: nil, lastInsertWasGlide: false).word, "Hello")
        XCTAssertEqual(GlideCommit.insertion(word: "hello", shift: .capsLocked,
                                             contextBefore: nil, lastInsertWasGlide: false).word, "HELLO")
    }

    // MARK: - Auto-space: only between consecutive glides, only after a letter

    func testConsecutiveGlidesAutoSpace() {
        let insertion = GlideCommit.insertion(word: "world", shift: .off,
                                              contextBefore: "hello", lastInsertWasGlide: true)
        XCTAssertEqual(insertion.text, " world")
        XCTAssertEqual(insertion.word, "world", "the word excludes the space — backspace keeps it")
    }

    func testAGlideAfterTappedTextDoesNotAutoSpace() {
        XCTAssertEqual(GlideCommit.insertion(word: "world", shift: .off,
                                             contextBefore: "hello", lastInsertWasGlide: false).text, "world")
    }

    func testAGlideAfterASpaceOrPunctuationDoesNotAutoSpace() {
        for context in ["hello ", "hello.", "", "5"] {
            let insertion = GlideCommit.insertion(word: "world", shift: .off,
                                                  contextBefore: context, lastInsertWasGlide: true)
            XCTAssertEqual(insertion.text, "world", "context '\(context)' must not auto-space")
        }
    }

    // MARK: - GlideUndo lifecycle

    func testConsumeReturnsTheLengthOnceAndDisarms() {
        let undo = GlideUndo()
        undo.record(wordLength: 5)
        XCTAssertTrue(undo.isArmed)
        XCTAssertEqual(undo.consume(), 5)
        XCTAssertNil(undo.consume())
        XCTAssertFalse(undo.isArmed)
    }

    func testAnyOtherKeystrokeDisarms() {
        let undo = GlideUndo()
        undo.record(wordLength: 5)
        undo.interrupt()
        XCTAssertNil(undo.consume())
    }

    /// The settle of our own insert arrives back as a host text change; that echo
    /// must not disarm, while a genuinely external edit must.
    func testTheEchoOfOurOwnEditPassesThroughButExternalEditsDisarm() {
        let undo = GlideUndo()
        undo.record(wordLength: 5)
        undo.noteLocalChange()
        undo.hostTextDidChange()          // the echo
        XCTAssertTrue(undo.isArmed)
        undo.hostTextDidChange()          // a cursor jump, a host-side clear
        XCTAssertFalse(undo.isArmed)
    }
}
