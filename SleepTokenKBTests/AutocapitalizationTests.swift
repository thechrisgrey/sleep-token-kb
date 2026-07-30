import XCTest
import UIKit
@testable import SleepTokenKB

/// Autocapitalisation is the one decision the keyboard makes by reading the *host field's*
/// intent rather than its own state, so it is kept as a pure function over
/// (type, preceding text, current shift) and pinned here. Driving it through a real
/// `UITextDocumentProxy` would need a live text field and would test UIKit, not this rule.
final class AutocapitalizationTests: XCTestCase {

    // MARK: - .sentences

    func testSentencesArmsShiftAtTheStartOfAnEmptyField() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: nil, current: .off),
            .shifted
        )
    }

    func testSentencesArmsShiftAfterATerminatorAndASpace() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello. ", current: .off),
            .shifted
        )
    }

    /// The space is what ends the sentence. Arming on the bare terminator would capitalise
    /// the decimal in "3.14".
    func testSentencesDoesNotArmShiftBeforeTheSpaceIsTyped() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello.", current: .off),
            .off
        )
    }

    func testSentencesDoesNotArmShiftMidSentence() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello wor", current: .off),
            .off
        )
    }

    func testSentencesDoesNotArmShiftAfterAPlainWordAndSpace() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "hello ", current: .off),
            .off
        )
    }

    func testSentencesTreatsANewlineAsASentenceBoundary() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello\n", current: .off),
            .shifted
        )
    }

    func testSentencesTreatsQuestionAndExclamationAsTerminators() {
        for terminator in [".", "?", "!"] {
            XCTAssertEqual(
                Autocapitalization.nextShift(for: .sentences, contextBefore: "Hey\(terminator) ", current: .off),
                .shifted,
                "\(terminator) should end a sentence"
            )
        }
    }

    /// A field holding only whitespace is still at its start.
    func testSentencesArmsShiftWhenOnlyWhitespaceHasBeenTyped() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "   ", current: .off),
            .shifted
        )
    }

    // MARK: - .words

    func testWordsArmsShiftAfterAnySpace() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .words, contextBefore: "hello ", current: .off),
            .shifted
        )
    }

    func testWordsArmsShiftAtTheStartOfAnEmptyField() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .words, contextBefore: nil, current: .off),
            .shifted
        )
    }

    func testWordsDoesNotArmShiftInsideAWord() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .words, contextBefore: "hel", current: .off),
            .off
        )
    }

    // MARK: - .allCharacters and .none

    func testAllCharactersLocksCaps() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .allCharacters, contextBefore: "abc", current: .off),
            .capsLocked
        )
    }

    func testNoneNeverArmsShift() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: UITextAutocapitalizationType.none, contextBefore: nil, current: .off),
            .off
        )
        XCTAssertEqual(
            Autocapitalization.nextShift(for: UITextAutocapitalizationType.none, contextBefore: "Hello. ", current: .off),
            .off
        )
    }

    /// A one-shot shift the user armed by hand must survive a decision that would not have
    /// armed it, otherwise tapping shift mid-sentence is cancelled before the next letter.
    func testAManuallyArmedShiftIsNotReleased() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "hello wor", current: .shifted),
            .shifted
        )
    }

    /// A user who has explicitly engaged caps lock has overridden the field's preference;
    /// autocapitalisation must not quietly release it between words.
    func testCapsLockSurvivesEveryAutocapitalizationType() {
        let types: [UITextAutocapitalizationType] = [.none, .words, .sentences, .allCharacters]
        for type in types {
            XCTAssertEqual(
                Autocapitalization.nextShift(for: type, contextBefore: "Hello. ", current: .capsLocked),
                .capsLocked,
                "caps lock must survive \(type.rawValue)"
            )
        }
    }
}
