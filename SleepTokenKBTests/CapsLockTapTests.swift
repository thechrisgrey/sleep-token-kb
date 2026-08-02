import XCTest
@testable import SleepTokenKB

/// Stock iOS engages caps lock on a *double tap* of shift. Our keyboard only had the
/// three-tap cycle (off -> shifted -> capsLocked -> off), which is a different muscle
/// memory. Both now work: the double tap is a shortcut into caps lock, and the cycle
/// still gets there on a slow third tap.
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

    func testWindowMatchesTheSystemDoubleTapFeel() {
        // Stock's shift double-tap is forgiving; anything under ~250ms is too strict
        // for a thumb, anything over ~500ms starts catching deliberate separate taps.
        XCTAssertGreaterThanOrEqual(CapsLockTap.window, 0.25)
        XCTAssertLessThanOrEqual(CapsLockTap.window, 0.5)
    }
}
