import XCTest
@testable import SleepTokenKB

/// Delete previously fired once per tap, so clearing a sentence took forty taps. The repeat
/// schedule is kept as pure arithmetic so the acceleration curve can be pinned here without
/// driving a real timer and waiting out the delays.
final class KeyRepeatTests: XCTestCase {

    /// The pause before the first repeat is what separates a tap from a hold; without it,
    /// an ordinary tap would delete two characters.
    func testTheFirstRepeatWaitsLongerThanSubsequentOnes() {
        XCTAssertGreaterThan(KeyRepeat.initialDelay, KeyRepeat.interval(forRepeat: 1))
    }

    func testEarlyRepeatsUseTheBaseInterval() {
        XCTAssertEqual(KeyRepeat.interval(forRepeat: 1), KeyRepeat.baseInterval)
        XCTAssertEqual(KeyRepeat.interval(forRepeat: KeyRepeat.accelerateAfter), KeyRepeat.baseInterval)
    }

    func testHoldingPastTheThresholdAccelerates() {
        XCTAssertEqual(
            KeyRepeat.interval(forRepeat: KeyRepeat.accelerateAfter + 1),
            KeyRepeat.fastInterval
        )
    }

    func testTheRateNeverSlowsDownMidHold() {
        let intervals = (1...40).map(KeyRepeat.interval(forRepeat:))
        for (earlier, later) in zip(intervals, intervals.dropFirst()) {
            XCTAssertLessThanOrEqual(later, earlier, "the repeat rate must never slow down mid-hold")
        }
    }

    /// A floor exists so a long hold cannot outrun the run loop and delete the whole field
    /// between two frames.
    func testTheIntervalNeverDropsBelowTheFloor() {
        for count in 1...500 {
            XCTAssertGreaterThanOrEqual(KeyRepeat.interval(forRepeat: count), KeyRepeat.fastInterval)
        }
    }

    /// Guards the call site: a zero or negative count must not yield a zero delay and spin
    /// the timer as fast as the CPU allows.
    func testANonPositiveRepeatCountStillWaits() {
        XCTAssertEqual(KeyRepeat.interval(forRepeat: 0), KeyRepeat.baseInterval)
        XCTAssertEqual(KeyRepeat.interval(forRepeat: -5), KeyRepeat.baseInterval)
    }

    func testEveryConstantIsAPositiveDuration() {
        XCTAssertGreaterThan(KeyRepeat.initialDelay, 0)
        XCTAssertGreaterThan(KeyRepeat.baseInterval, 0)
        XCTAssertGreaterThan(KeyRepeat.fastInterval, 0)
        XCTAssertGreaterThan(KeyRepeat.accelerateAfter, 0)
    }

    func testTheFastIntervalIsActuallyFasterThanTheBase() {
        XCTAssertLessThan(KeyRepeat.fastInterval, KeyRepeat.baseInterval)
    }
}
