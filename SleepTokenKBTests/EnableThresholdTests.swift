import XCTest
@testable import SleepTokenKB

/// The welcome's one state-aware element. The rule's bias is deliberate: showing
/// setup to someone who finished it is a shrug, hiding it from someone who has
/// not is a dead end — so every unreadable state keeps the card.
final class EnableThresholdTests: XCTestCase {

    private let enabled = ["en_US@sw=QWERTY", EnableThreshold.keyboardBundleID]

    func testAnEnabledKeyboardHidesTheCard() {
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: enabled,
                                                       manuallyHidden: false))
    }

    func testAMissingKeyboardShowsTheCard() {
        XCTAssertTrue(EnableThreshold.showsEnableCard(enabledKeyboards: ["en_US@sw=QWERTY"],
                                                      manuallyHidden: false))
    }

    /// The degraded read: nil (preference unreadable) and empty both keep the card.
    func testAnUnreadableListShowsTheCard() {
        XCTAssertTrue(EnableThreshold.showsEnableCard(enabledKeyboards: nil, manuallyHidden: false))
        XCTAssertTrue(EnableThreshold.showsEnableCard(enabledKeyboards: [], manuallyHidden: false))
    }

    /// The manual override wins over everything, including a readable list that
    /// lacks the keyboard — it exists precisely for when the read lies.
    func testManualHideWinsRegardlessOfTheList() {
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: nil, manuallyHidden: true))
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: ["other"], manuallyHidden: true))
        XCTAssertFalse(EnableThreshold.showsEnableCard(enabledKeyboards: enabled, manuallyHidden: true))
    }
}
