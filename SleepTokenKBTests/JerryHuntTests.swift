import XCTest
@testable import SleepTokenKB

/// The Jerry hunt's logic layer: ten spots, persistence, and the
/// exactly-once celebration trigger.
final class JerryHuntTests: XCTestCase {
    private var suite: UserDefaults!

    override func setUpWithError() throws {
        suite = try XCTUnwrap(UserDefaults(suiteName: "JerryHuntTests-scratch"))
        suite.removeObject(forKey: JerryHunt.foundKey)
        suite.removeObject(forKey: JerryHunt.celebratedKey)
    }

    override func tearDownWithError() throws {
        suite.removeObject(forKey: JerryHunt.foundKey)
        suite.removeObject(forKey: JerryHunt.celebratedKey)
    }

    func testThereAreExactlyTenSpots() {
        XCTAssertEqual(JerrySpot.allCases.count, 10)
    }

    /// Raw values are the on-disk format — a rename resets fans mid-hunt.
    func testSpotRawValuesAreStable() {
        XCTAssertEqual(
            JerrySpot.allCases.map(\.rawValue),
            [
                "heroRow", "waysCard", "appearanceCard", "homeFooter",
                "setupCard", "troubleshooting", "chartIntro", "chartFoot",
                "runeCanvas", "runeToolbar"
            ]
        )
    }

    func testFindingIsIdempotentAndPersists() {
        let hunt = JerryHunt(defaults: suite)
        hunt.find(.heroRow)
        hunt.find(.heroRow)
        XCTAssertEqual(hunt.found.count, 1)

        // A fresh store over the same suite sees the same progress.
        XCTAssertEqual(JerryHunt(defaults: suite).found, [.heroRow])
    }

    func testUnknownStoredSpotIsDroppedNotFatal() {
        suite.set(["heroRow", "retired-spot"], forKey: JerryHunt.foundKey)
        XCTAssertEqual(JerryHunt(defaults: suite).found, [.heroRow])
    }

    func testCelebrationFiresExactlyOnceOnTheTenthFind() {
        let hunt = JerryHunt(defaults: suite)
        for spot in JerrySpot.allCases.dropLast() {
            hunt.find(spot)
            XCTAssertFalse(hunt.celebrationPending, "\(spot) is not the tenth")
        }
        hunt.find(JerrySpot.allCases.last!)
        XCTAssertTrue(hunt.celebrationPending)
        XCTAssertTrue(hunt.isComplete)

        hunt.celebrationDidFinish()
        XCTAssertFalse(hunt.celebrationPending)
        XCTAssertTrue(hunt.hasCelebrated)

        // Completing again (or re-finding) never re-arms the ceremony,
        // and a relaunch remembers that it already played.
        hunt.find(.heroRow)
        XCTAssertFalse(hunt.celebrationPending)
        XCTAssertTrue(JerryHunt(defaults: suite).hasCelebrated)
    }

    func testDamoclesLinkIsTheAppleMusicSong() {
        XCTAssertEqual(JerryHunt.damoclesURL.host(), "music.apple.com")
        XCTAssertTrue(JerryHunt.damoclesURL.path().contains("/song/damocles/"))
    }
}
