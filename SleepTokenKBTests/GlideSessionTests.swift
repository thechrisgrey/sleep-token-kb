// SleepTokenKBTests/GlideSessionTests.swift
import XCTest
@testable import SleepTokenKB

final class GlideSessionTests: XCTestCase {

    func testASingleGestureAccumulatesFromOneStart() {
        var session = GlideSession()
        XCTAssertFalse(session.isActive)
        session.extend(start: CGPoint(x: 1, y: 1), to: CGPoint(x: 5, y: 5))
        session.extend(start: CGPoint(x: 1, y: 1), to: CGPoint(x: 9, y: 9))
        XCTAssertEqual(session.points,
                       [CGPoint(x: 1, y: 1), CGPoint(x: 5, y: 5), CGPoint(x: 9, y: 9)],
                       "one drag keeps one start; its samples accumulate")
    }

    func testFinishReturnsTheTraceAndResets() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        let trace = session.finish(at: CGPoint(x: 10, y: 0))
        XCTAssertEqual(trace, [.zero, CGPoint(x: 5, y: 0), CGPoint(x: 10, y: 0)])
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(session.points.isEmpty)
    }

    /// A system-cancelled touch never calls finish OR cancel; the stale session
    /// must still not leak its points into the next glide. A differing start is
    /// the signal: one drag keeps one startLocation for its whole life.
    func testANewGestureReplacesAStaleSession() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        // Deliberately no cancel() and no finish(): the touch was abandoned.
        session.extend(start: CGPoint(x: 50, y: 50), to: CGPoint(x: 60, y: 50))
        XCTAssertEqual(session.points,
                       [CGPoint(x: 50, y: 50), CGPoint(x: 60, y: 50)],
                       "the stale trace must be replaced, not continued")
    }

    /// cancel() still exists for the explicit paths (page change, VoiceOver
    /// engaging mid-glide) and must leave the session idle.
    func testCancelLeavesTheSessionIdle() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        session.cancel()
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(session.points.isEmpty)
    }

    func testFinishOnAnIdleSessionReturnsEmpty() {
        var session = GlideSession()
        XCTAssertTrue(session.finish(at: .zero).isEmpty)
    }
}
