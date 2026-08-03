import XCTest
@testable import SleepTokenKB

/// Counts without hinting. Nothing before the first find — a newcomer never
/// learns from the UI that a hunt exists — and the reward's replay line only
/// once every Jerry is home.
final class JerryTallyTests: XCTestCase {

    func testNothingBeforeTheFirstFind() {
        XCTAssertNil(JerryTally.presentation(found: 0, total: 10))
    }

    func testCountsAreWrittenOut() {
        XCTAssertEqual(JerryTally.presentation(found: 1, total: 10)?.text, "One of ten")
        XCTAssertEqual(JerryTally.presentation(found: 4, total: 10)?.text, "Four of ten")
        XCTAssertEqual(JerryTally.presentation(found: 9, total: 10)?.text, "Nine of ten")
    }

    func testTheReplayLineAppearsOnlyAtTen() {
        XCTAssertEqual(JerryTally.presentation(found: 9, total: 10)?.showsReplay, false)
        let complete = JerryTally.presentation(found: 10, total: 10)
        XCTAssertEqual(complete?.text, "Ten of ten")
        XCTAssertEqual(complete?.showsReplay, true)
    }
}
