import XCTest
@testable import SleepTokenKB

final class LayoutModeTests: XCTestCase {
    func testOnlyRuneHintsShowsTheLatinHint() {
        XCTAssertFalse(KeyFaceStyle.runeArt.showsLatinHint)
        XCTAssertTrue(KeyFaceStyle.runeHints.showsLatinHint)
        XCTAssertFalse(KeyFaceStyle.letters.showsLatinHint)
    }

    /// The options panel renders `shortTitle` on its buttons; three distinct strings are
    /// load-bearing — two faces sharing a title would be two identical buttons.
    func testShortTitlesAreDistinct() {
        let titles = KeyFaceStyle.allCases.map(\.shortTitle)
        XCTAssertEqual(Set(titles).count, titles.count)
    }

    /// The panel speaks the full name, never the chrome short form: "Rune·A" and "A–Z"
    /// read unpredictably, so every option pairs its short title with a spoken one.
    func testEveryOptionHasASpokenNameDistinctFromItsShortTitle() {
        for style in KeyFaceStyle.allCases {
            XCTAssertFalse(style.title.isEmpty)
            XCTAssertNotEqual(style.title, style.shortTitle)
        }
        for mode in LayoutMode.allCases {
            XCTAssertFalse(mode.accessibilityLabel.isEmpty)
            XCTAssertNotEqual(mode.accessibilityLabel, mode.shortTitle)
        }
    }
}
