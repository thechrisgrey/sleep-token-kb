import XCTest
@testable import SleepTokenKB

final class LayoutModeTests: XCTestCase {
    func testLayoutModeNextCyclesBetweenQwertyAndGrid() {
        XCTAssertEqual(LayoutMode.qwerty.next, .grid)
        XCTAssertEqual(LayoutMode.grid.next, .qwerty)
    }

    func testKeyFaceStyleNextCycles() {
        XCTAssertEqual(KeyFaceStyle.runeArt.next, .letters)
        XCTAssertEqual(KeyFaceStyle.letters.next, .runeArt)
    }
}
