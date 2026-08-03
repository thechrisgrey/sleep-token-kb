import XCTest
import UIKit
@testable import SleepTokenKB

/// The sequences the 2026-07-31 audit proved untestable under the old API: every test
/// hands `nextShift` a `current` state whose origin the test knows, but the production
/// caller is precisely the party that lost that information. `AutoShift` carries the
/// provenance, so the ratchet, the impossible cancel, and the caps-lock latch become
/// expressible as plain sequences here.
final class AutoShiftTests: XCTestCase {

    // MARK: - The ratchet

    /// The audit's headline failure: "Hello. " arms shift; deleting back to "Hello"
    /// must disarm it. The old rule preserved any engaged state, so the next letter
    /// came out wrongly uppercase.
    func testDeletingBackIntoAWordDisarmsAnAutoArmedShift() {
        var shift = AutoShift()
        shift.apply(type: .sentences, contextBefore: "Hello. ")
        XCTAssertEqual(shift.state, .shifted)

        shift.apply(type: .sentences, contextBefore: "Hello.")
        XCTAssertEqual(shift.state, .off, "auto-armed shift must release when context no longer warrants it")

        shift.apply(type: .sentences, contextBefore: "Hello")
        XCTAssertEqual(shift.state, .off)
    }

    /// Leaving the trigger context releases an auto caps lock too. (The field-change
    /// wiring is separate; this pins the rule-level behaviour it depends on.)
    func testAutoCapsLockReleasesWhenTheFieldTypeChanges() {
        var shift = AutoShift()
        shift.apply(type: .allCharacters, contextBefore: "AB")
        XCTAssertEqual(shift.state, .capsLocked)

        shift.apply(type: .sentences, contextBefore: "AB and then ")
        XCTAssertEqual(shift.state, .off, "an auto caps lock must not outlive the .allCharacters field that armed it")
    }

    // MARK: - The cancel

    /// On the system keyboard, tapping the highlighted auto-shift disarms it. The old
    /// cycle sent .shifted to .capsLocked instead, so the standard lowercase-typist
    /// move produced ALL CAPS.
    func testTappingShiftCancelsAnAutoArmedShift() {
        var shift = AutoShift()
        shift.apply(type: .sentences, contextBefore: nil)
        XCTAssertEqual(shift.state, .shifted)

        shift.userTappedShift()
        XCTAssertEqual(shift.state, .off, "one tap on an auto-armed shift must cancel, not escalate to caps lock")
    }

    /// Stock's shift is a toggle at any speed: a second tap on a manual shift releases
    /// it. Caps lock belongs to the double tap (`setCapsLock`) — the old slow cycle's
    /// middle step turned a change of mind into ALL CAPS.
    func testASecondTapOnAManualShiftReleasesIt() {
        var shift = AutoShift()
        shift.userTappedShift()
        XCTAssertEqual(shift.state, .shifted)

        shift.userTappedShift()
        XCTAssertEqual(shift.state, .off, "a slow second tap must release, not escalate to caps lock")
    }

    /// The road out of caps lock is one tap, whatever engaged it.
    func testTappingCapsLockReleasesIt() {
        var shift = AutoShift()
        shift.setCapsLock()
        shift.userTappedShift()
        XCTAssertEqual(shift.state, .off)
    }

    // MARK: - Manual states still outrank the field

    func testAManualShiftSurvivesDerivation() {
        var shift = AutoShift()
        shift.userTappedShift()
        shift.apply(type: .sentences, contextBefore: "hello wor")
        XCTAssertEqual(shift.state, .shifted, "a shift the user armed mid-sentence must survive derivation")
    }

    func testAManualCapsLockSurvivesEveryFieldType() {
        for type in [UITextAutocapitalizationType.none, .words, .sentences, .allCharacters] {
            var shift = AutoShift()
            shift.setCapsLock()
            XCTAssertEqual(shift.state, .capsLocked)

            shift.apply(type: type, contextBefore: "Hello. ")
            XCTAssertEqual(shift.state, .capsLocked, "manual caps lock must survive \(type.rawValue)")
        }
    }

    // MARK: - Insertion consumes correctly

    func testInsertingALetterConsumesAOneShotAndReArmsOnlyPerContext() {
        var shift = AutoShift()
        shift.apply(type: .sentences, contextBefore: nil)
        XCTAssertEqual(shift.state, .shifted)
        XCTAssertTrue(shift.state.isUppercase)

        shift.didInsertLetter()
        shift.apply(type: .sentences, contextBefore: "H")
        XCTAssertEqual(shift.state, .off, "mid-word after the capital, shift must be down")
    }

    func testManualCapsLockPersistsAcrossInserts() {
        var shift = AutoShift()
        shift.setCapsLock()
        shift.didInsertLetter()
        shift.apply(type: .sentences, contextBefore: "A")
        XCTAssertEqual(shift.state, .capsLocked)
    }

    // MARK: - Declining the field's caps lock

    /// The audit's one-letter cancel: turning caps off in an `.allCharacters` field
    /// bought exactly one lowercase letter before derivation re-locked it. The
    /// declination now outlives every re-derivation in the field.
    func testCancellingCapsInAnAllCharactersFieldSticks() {
        var shift = AutoShift()
        shift.apply(type: .allCharacters, contextBefore: "AB")
        XCTAssertEqual(shift.state, .capsLocked)

        shift.userTappedShift()
        XCTAssertEqual(shift.state, .off)

        shift.didInsertLetter()
        shift.apply(type: .allCharacters, contextBefore: "ABc")
        XCTAssertEqual(shift.state, .off, "the declined lock must not re-arm one letter later")

        shift.didInsertLetter()
        shift.apply(type: .allCharacters, contextBefore: "ABcd")
        XCTAssertEqual(shift.state, .off)
    }

    /// The declination is per-field state: the view resets to a fresh AutoShift() on
    /// every field change, and a fresh field derives its caps lock again.
    func testAFreshAutoShiftDerivesCapsAgain() {
        var shift = AutoShift()
        shift.apply(type: .allCharacters, contextBefore: nil)
        shift.userTappedShift()

        shift = AutoShift()
        shift.apply(type: .allCharacters, contextBefore: nil)
        XCTAssertEqual(shift.state, .capsLocked)
    }

    /// Asking for the lock again withdraws the declination: the double tap after a
    /// cancel is a fresh manual caps lock and survives derivation like one.
    func testSetCapsLockWithdrawsTheDeclination() {
        var shift = AutoShift()
        shift.apply(type: .allCharacters, contextBefore: nil)
        shift.userTappedShift()

        shift.setCapsLock()
        shift.apply(type: .allCharacters, contextBefore: "A")
        XCTAssertEqual(shift.state, .capsLocked, "a re-requested lock is manual and must survive")
    }

    /// Declining the lock silences only the lock: sentence-start shifts still arm.
    func testDecliningCapsStillAllowsSentenceShifts() {
        var shift = AutoShift()
        shift.setCapsLock()
        shift.userTappedShift()

        shift.apply(type: .sentences, contextBefore: "Hello. ")
        XCTAssertEqual(shift.state, .shifted, "declining the lock must not silence sentence-start shifts")
    }

    /// A consumed one-shot's provenance must not leak: after the letter, a manual
    /// re-tap is a fresh manual arm, and cancelling it must not happen by accident.
    func testProvenanceClearsWhenAOneShotIsConsumed() {
        var shift = AutoShift()
        shift.apply(type: .sentences, contextBefore: nil)
        shift.didInsertLetter()

        shift.userTappedShift()
        XCTAssertEqual(shift.state, .shifted)
        shift.apply(type: .sentences, contextBefore: "Hi the")
        XCTAssertEqual(shift.state, .shifted, "the fresh tap is manual and must survive")
    }

    // MARK: - Least privilege

    /// The host document must not be read when the decision cannot depend on it:
    /// a .none field never needs context, and a manual engaged state is preserved
    /// without looking. `apply` takes the context as an autoclosure precisely so
    /// this is enforceable by construction; these assertions pin it.
    func testContextIsNotReadWhenTheDecisionCannotDependOnIt() {
        var shift = AutoShift()
        XCTAssertEqual(shift.applyCounting(type: UITextAutocapitalizationType.none), 0,
                       ".none must not read the document")

        shift = AutoShift()
        shift.userTappedShift()
        XCTAssertEqual(shift.applyCounting(type: .sentences), 0,
                       "a preserved manual shift must not read the document")

        shift = AutoShift()
        XCTAssertEqual(shift.applyCounting(type: .sentences), 1,
                       "a real derivation reads the document exactly once")
    }
}

private extension AutoShift {
    /// Calls through the public autoclosure API and reports how many times the
    /// context expression was actually evaluated. If `apply` ever takes the context
    /// as a plain value this always returns 1 and the zero-read assertions fail,
    /// which is exactly the regression signal wanted.
    mutating func applyCounting(type: UITextAutocapitalizationType) -> Int {
        var count = 0
        apply(type: type, contextBefore: { count += 1; return "Hello. " }())
        return count
    }
}
