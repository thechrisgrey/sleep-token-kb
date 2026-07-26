import XCTest
@testable import SleepTokenKB

/// Pins the exact shift table the keyboard shipped when this was two overlapping Bools,
/// so extracting it into an enum cannot have changed behaviour.
final class ShiftStateTests: XCTestCase {

    func testTapCyclesOffToShiftedToCapsLockedToOff() {
        XCTAssertEqual(ShiftState.off.toggled(), .shifted)
        XCTAssertEqual(ShiftState.shifted.toggled(), .capsLocked)
        XCTAssertEqual(ShiftState.capsLocked.toggled(), .off)
    }

    func testThreeTapsReturnToStart() {
        let end = ShiftState.off.toggled().toggled().toggled()
        XCTAssertEqual(end, .off)
    }

    func testOneShotShiftFallsAwayAfterInsert() {
        XCTAssertEqual(ShiftState.shifted.afterInsert(), .off)
    }

    func testCapsLockPersistsAcrossInserts() {
        XCTAssertEqual(ShiftState.capsLocked.afterInsert(), .capsLocked)
        XCTAssertEqual(ShiftState.capsLocked.afterInsert().afterInsert(), .capsLocked)
    }

    func testOffStaysOffAfterInsert() {
        XCTAssertEqual(ShiftState.off.afterInsert(), .off)
    }

    func testIsUppercaseOnlyWhenShiftedOrCapsLocked() {
        XCTAssertFalse(ShiftState.off.isUppercase)
        XCTAssertTrue(ShiftState.shifted.isUppercase)
        XCTAssertTrue(ShiftState.capsLocked.isUppercase)
    }

    /// The bug this extraction fixed: the key could not tell the two engaged states apart.
    func testEachStateIsVisuallyAndAudiblyDistinct() {
        let symbols = ShiftState.allCases.map(\.symbolName)
        XCTAssertEqual(Set(symbols).count, ShiftState.allCases.count, "shift states must not share an icon")

        let values = ShiftState.allCases.map(\.accessibilityValue)
        XCTAssertEqual(Set(values).count, ShiftState.allCases.count, "shift states must not share a VoiceOver value")
    }
}
