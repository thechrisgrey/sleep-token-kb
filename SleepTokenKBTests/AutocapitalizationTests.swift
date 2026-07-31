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
            Autocapitalization.nextShift(for: .sentences, contextBefore: nil, current: .off, autoArmed: false),
            .shifted
        )
    }

    func testSentencesArmsShiftAfterATerminatorAndASpace() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello. ", current: .off, autoArmed: false),
            .shifted
        )
    }

    /// The space is what ends the sentence. Arming on the bare terminator would capitalise
    /// the decimal in "3.14".
    func testSentencesDoesNotArmShiftBeforeTheSpaceIsTyped() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello.", current: .off, autoArmed: false),
            .off
        )
    }

    func testSentencesDoesNotArmShiftMidSentence() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello wor", current: .off, autoArmed: false),
            .off
        )
    }

    func testSentencesDoesNotArmShiftAfterAPlainWordAndSpace() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "hello ", current: .off, autoArmed: false),
            .off
        )
    }

    func testSentencesTreatsANewlineAsASentenceBoundary() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello\n", current: .off, autoArmed: false),
            .shifted
        )
    }

    func testSentencesTreatsQuestionAndExclamationAsTerminators() {
        for terminator in [".", "?", "!"] {
            XCTAssertEqual(
                Autocapitalization.nextShift(for: .sentences, contextBefore: "Hey\(terminator) ", current: .off, autoArmed: false),
                .shifted,
                "\(terminator) should end a sentence"
            )
        }
    }

    /// A field holding only whitespace is still at its start.
    func testSentencesArmsShiftWhenOnlyWhitespaceHasBeenTyped() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "   ", current: .off, autoArmed: false),
            .shifted
        )
    }

    // MARK: - .words

    func testWordsArmsShiftAfterAnySpace() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .words, contextBefore: "hello ", current: .off, autoArmed: false),
            .shifted
        )
    }

    func testWordsArmsShiftAtTheStartOfAnEmptyField() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .words, contextBefore: nil, current: .off, autoArmed: false),
            .shifted
        )
    }

    func testWordsDoesNotArmShiftInsideAWord() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .words, contextBefore: "hel", current: .off, autoArmed: false),
            .off
        )
    }

    // MARK: - .allCharacters and .none

    func testAllCharactersLocksCaps() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .allCharacters, contextBefore: "abc", current: .off, autoArmed: false),
            .capsLocked
        )
    }

    func testNoneNeverArmsShift() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: UITextAutocapitalizationType.none, contextBefore: nil, current: .off, autoArmed: false),
            .off
        )
        XCTAssertEqual(
            Autocapitalization.nextShift(for: UITextAutocapitalizationType.none, contextBefore: "Hello. ", current: .off, autoArmed: false),
            .off
        )
    }

    // MARK: - Closing punctuation

    /// `He said "stop." ` ends a sentence; the closing quote between the terminator and
    /// the space must not defeat detection. Same for brackets.
    func testSentencesArmsShiftAfterATerminatorInsideClosingPunctuation() {
        for context in ["He said \"stop.\" ", "(Done.) ", "He said 'go.' ", "[Fine.] ", "It works.\u{201D} "] {
            XCTAssertEqual(
                Autocapitalization.nextShift(for: .sentences, contextBefore: context, current: .off, autoArmed: false),
                .shifted,
                "\(context.debugDescription) should arm shift"
            )
        }
    }

    /// A bare closer after a word is not a sentence end: `(soon) ` continues the sentence.
    func testAClosingBracketWithoutATerminatorDoesNotArmShift() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "(soon) ", current: .off, autoArmed: false),
            .off
        )
    }

    // MARK: - Provenance

    /// The rule that closes the audit's ratchet: an AUTO-armed engaged state is re-derived
    /// from context, not preserved. Only a manual state outranks the field.
    func testAnAutoArmedShiftIsReDerivedNotPreserved() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello", current: .shifted, autoArmed: true),
            .off,
            "auto-armed shift must release mid-word"
        )
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "Hello. ", current: .shifted, autoArmed: true),
            .shifted,
            "auto-armed shift stays armed while the context still warrants it"
        )
    }

    func testAnAutoCapsLockIsReDerivedNotPreserved() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "AB and ", current: .capsLocked, autoArmed: true),
            .off,
            "auto caps lock must not survive outside the .allCharacters field that armed it"
        )
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .allCharacters, contextBefore: "AB", current: .capsLocked, autoArmed: true),
            .capsLocked
        )
    }

    /// A one-shot shift the user armed by hand must survive a decision that would not have
    /// armed it, otherwise tapping shift mid-sentence is cancelled before the next letter.
    func testAManuallyArmedShiftIsNotReleased() {
        XCTAssertEqual(
            Autocapitalization.nextShift(for: .sentences, contextBefore: "hello wor", current: .shifted, autoArmed: false),
            .shifted
        )
    }

    /// A user who has explicitly engaged caps lock has overridden the field's preference;
    /// autocapitalisation must not quietly release it between words.
    func testCapsLockSurvivesEveryAutocapitalizationType() {
        let types: [UITextAutocapitalizationType] = [.none, .words, .sentences, .allCharacters]
        for type in types {
            XCTAssertEqual(
                Autocapitalization.nextShift(for: type, contextBefore: "Hello. ", current: .capsLocked, autoArmed: false),
                .capsLocked,
                "caps lock must survive \(type.rawValue)"
            )
        }
    }
}
