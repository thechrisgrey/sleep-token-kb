import XCTest
@testable import SleepTokenKB

final class LayoutModeTests: XCTestCase {
    func testLayoutModeNextCyclesBetweenQwertyAndGrid() {
        XCTAssertEqual(LayoutMode.qwerty.next, .grid)
        XCTAssertEqual(LayoutMode.grid.next, .qwerty)
    }

    func testKeyFaceStyleNextCyclesThroughAllThreeFaces() {
        XCTAssertEqual(KeyFaceStyle.runeArt.next, .runeHints)
        XCTAssertEqual(KeyFaceStyle.runeHints.next, .letters)
        XCTAssertEqual(KeyFaceStyle.letters.next, .runeArt)
    }

    /// The cycle must visit every case before repeating — a fourth style added without
    /// wiring `next` would silently become unreachable from the keyboard's chrome key.
    func testKeyFaceStyleCycleVisitsEveryCase() {
        var seen: Set<KeyFaceStyle> = []
        var current = KeyFaceStyle.runeArt
        for _ in 0..<KeyFaceStyle.allCases.count {
            seen.insert(current)
            current = current.next
        }
        XCTAssertEqual(seen, Set(KeyFaceStyle.allCases))
        XCTAssertEqual(current, .runeArt)
    }

    func testOnlyRuneHintsShowsTheLatinHint() {
        XCTAssertFalse(KeyFaceStyle.runeArt.showsLatinHint)
        XCTAssertTrue(KeyFaceStyle.runeHints.showsLatinHint)
        XCTAssertFalse(KeyFaceStyle.letters.showsLatinHint)
    }

    func testLettersIsTheOnlyFaceWithoutRuneArt() {
        XCTAssertTrue(KeyFaceStyle.runeArt.showsRuneArt)
        XCTAssertTrue(KeyFaceStyle.runeHints.showsRuneArt)
        XCTAssertFalse(KeyFaceStyle.letters.showsRuneArt)
    }

    /// The chrome key renders `shortTitle`; three distinct strings are load-bearing —
    /// two faces sharing a title would make the cycle look broken mid-tap.
    func testShortTitlesAreDistinct() {
        let titles = KeyFaceStyle.allCases.map(\.shortTitle)
        XCTAssertEqual(Set(titles).count, titles.count)
    }
}
