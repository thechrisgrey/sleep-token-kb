// SleepTokenKBTests/GlideSessionTests.swift
import XCTest
@testable import SleepTokenKB

final class GlideSessionTests: XCTestCase {

    func testExtendRecordsTheStartExactlyOnce() {
        var session = GlideSession()
        XCTAssertFalse(session.isActive)
        session.extend(start: CGPoint(x: 1, y: 1), to: CGPoint(x: 5, y: 5))
        session.extend(start: CGPoint(x: 99, y: 99), to: CGPoint(x: 9, y: 9))
        XCTAssertEqual(session.points.first, CGPoint(x: 1, y: 1),
                       "a second start must not restart an active session")
        XCTAssertEqual(session.points.count, 3)
    }

    func testFinishReturnsTheTraceAndResets() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        let trace = session.finish(at: CGPoint(x: 10, y: 0))
        XCTAssertEqual(trace, [.zero, CGPoint(x: 5, y: 0), CGPoint(x: 10, y: 0)])
        XCTAssertFalse(session.isActive)
        XCTAssertTrue(session.points.isEmpty)
    }

    /// A system-cancelled touch never calls finish; the stale session must not
    /// leak its points into the next glide.
    func testANewGestureReplacesAStaleSession() {
        var session = GlideSession()
        session.extend(start: .zero, to: CGPoint(x: 5, y: 0))
        session.cancel()
        XCTAssertFalse(session.isActive)
        session.extend(start: CGPoint(x: 50, y: 50), to: CGPoint(x: 60, y: 50))
        XCTAssertEqual(session.points.first, CGPoint(x: 50, y: 50))
    }

    func testFinishOnAnIdleSessionReturnsEmpty() {
        var session = GlideSession()
        XCTAssertTrue(session.finish(at: .zero).isEmpty)
    }
}
