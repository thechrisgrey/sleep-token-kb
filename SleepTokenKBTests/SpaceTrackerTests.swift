import XCTest
@testable import SleepTokenKB

/// The double-space window must die on any document change this keyboard did not cause
/// — a cursor jump, a host-side clear, focusing a same-trait field — while surviving
/// the asynchronous echo of the keyboard's own keystroke. The final review found both
/// halves missing: nothing external interrupted the window, and a naive interrupt on
/// every host change would have killed the shortcut outright (the first space's own
/// settle arrives as a host change).
final class SpaceTrackerTests: XCTestCase {

    func testASpaceOpensTheWindow() {
        let tracker = SpaceTracker()
        tracker.noteLocalChange()
        tracker.recordSpace()
        XCTAssertTrue(tracker.sinceLastSpace.isFinite)
    }

    func testInterruptClosesTheWindow() {
        let tracker = SpaceTracker()
        tracker.recordSpace()
        tracker.interrupt()
        XCTAssertEqual(tracker.sinceLastSpace, .infinity)
    }

    /// The keyboard's own keystroke settles asynchronously and arrives back as a host
    /// text change; that echo must not break the window it just opened.
    func testTheEchoOfALocalKeystrokeDoesNotCloseTheWindow() {
        let tracker = SpaceTracker()
        tracker.noteLocalChange()
        tracker.recordSpace()
        tracker.hostTextDidChange()
        XCTAssertTrue(tracker.sinceLastSpace.isFinite, "the keystroke's own echo must be consumed silently")
    }

    /// A host change with no local keystroke behind it — a cursor jump, a host clear, a
    /// same-trait field switch — is an interleaving event and closes the window.
    func testAnExternalHostChangeClosesTheWindow() {
        let tracker = SpaceTracker()
        tracker.noteLocalChange()
        tracker.recordSpace()
        tracker.hostTextDidChange()

        tracker.hostTextDidChange()
        XCTAssertEqual(tracker.sinceLastSpace, .infinity, "a change the keyboard did not cause must break consecutiveness")
    }

    /// One local keystroke earns exactly one silent echo; the pending flag must not
    /// accumulate and swallow later external changes.
    func testAnEchoIsConsumedOnce() {
        let tracker = SpaceTracker()
        tracker.noteLocalChange()
        tracker.hostTextDidChange()
        tracker.recordSpace()

        tracker.hostTextDidChange()
        XCTAssertEqual(tracker.sinceLastSpace, .infinity)
    }
}
