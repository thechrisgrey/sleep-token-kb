import XCTest
@testable import SleepTokenKB

/// Stock iOS engages caps lock on a *double tap* of shift. Our keyboard once walked a
/// three-tap cycle instead; now the double tap is the road into caps lock and a tap on
/// the locked state is the road out, exactly stock's model.
///
/// Timing is injected rather than read from a clock so the window is testable.
final class CapsLockTapTests: XCTestCase {

    func testTwoQuickTapsEngageCapsLock() {
        var tracker = CapsLockTap()
        XCTAssertFalse(tracker.isDoubleTap(at: 0))
        XCTAssertTrue(tracker.isDoubleTap(at: 0.2))
    }

    func testTapsOutsideTheWindowAreNotADoubleTap() {
        var tracker = CapsLockTap()
        XCTAssertFalse(tracker.isDoubleTap(at: 0))
        XCTAssertFalse(tracker.isDoubleTap(at: CapsLockTap.window + 0.05))
    }

    /// Three quick taps must not read as two overlapping double taps, or caps lock
    /// would engage and immediately re-engage.
    func testDoubleTapConsumesTheWindow() {
        var tracker = CapsLockTap()
        XCTAssertFalse(tracker.isDoubleTap(at: 0))
        XCTAssertTrue(tracker.isDoubleTap(at: 0.15))
        XCTAssertFalse(tracker.isDoubleTap(at: 0.30))
    }

    /// A field switch or an external text change abandons the pending tap.
    func testInterruptClearsThePendingTap() {
        var tracker = CapsLockTap()
        XCTAssertFalse(tracker.isDoubleTap(at: 0))
        tracker.interrupt()
        XCTAssertFalse(tracker.isDoubleTap(at: 0.1))
    }

    /// A keystroke between two shift taps means they were never a double tap:
    /// shift-letter-shift at typing speed is two one-shots, not a caps lock. The view
    /// delivers the keystroke as an interrupt; this pins the sequence at rule level.
    func testAKeystrokeBetweenTapsBreaksTheDoubleTap() {
        var tracker = CapsLockTap()
        XCTAssertFalse(tracker.isDoubleTap(at: 0))
        tracker.interrupt()   // the letter landing between the taps
        XCTAssertFalse(tracker.isDoubleTap(at: 0.2), "the window must not survive a keystroke")
        XCTAssertTrue(tracker.isDoubleTap(at: 0.3), "the interrupted tap still starts a fresh window")
    }

    func testWindowMatchesTheSystemDoubleTapFeel() {
        // Stock's shift double-tap is forgiving; anything under ~250ms is too strict
        // for a thumb, anything over ~500ms starts catching deliberate separate taps.
        XCTAssertGreaterThanOrEqual(CapsLockTap.window, 0.25)
        XCTAssertLessThanOrEqual(CapsLockTap.window, 0.5)
    }
}
