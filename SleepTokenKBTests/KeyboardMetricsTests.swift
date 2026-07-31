import XCTest
@testable import SleepTokenKB

/// Regression cover for the height bug: the container used to reserve six hand-maintained
/// literals while the content laid itself out from unrelated private constants, so the
/// grid layout overflowed its own keyboard by ~48pt and lost its top key row off-screen.
///
/// Both sides now call `KeyboardMetrics`, and these tests pin the arithmetic.
final class KeyboardMetricsTests: XCTestCase {

    private let allPages = KeyboardMetrics.Page.allCases
    private let allModes = LayoutMode.allCases
    private let allStyles = KeyFaceStyle.allCases

    /// The invariant the old code violated: the height the controller reserves must never
    /// be less than the height the rows actually occupy.
    func testReservedHeightAlwaysCoversContentForEveryConfiguration() {
        for page in allPages {
            for mode in allModes {
                for style in allStyles {
                    for compact in [true, false] {
                        let needed = KeyboardMetrics.contentHeight(
                            page: page, mode: mode, style: style, compact: compact
                        )
                        let reserved = KeyboardMetrics.maxContentHeight(
                            page: page, mode: mode, compact: compact
                        )
                        XCTAssertGreaterThanOrEqual(
                            reserved, needed,
                            "\(page)/\(mode)/\(style)/compact:\(compact) reserves \(reserved) but needs \(needed)"
                        )
                    }
                }
            }
        }
    }

    /// Grid and symbols each render a dedicated shift/backspace row that the old literal
    /// table never counted. That undercount is the bug.
    func testGridAndSymbolsCarryOneMoreRowThanQwerty() {
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .letters, mode: .qwerty), 3)
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .letters, mode: .grid), 4)
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .symbols, mode: .qwerty), 4)
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .symbols, mode: .grid), 4)
    }

    func testGridIsTallerThanQwerty() {
        let qwerty = KeyboardMetrics.contentHeight(page: .letters, mode: .qwerty, style: .runeArt)
        let grid = KeyboardMetrics.contentHeight(page: .letters, mode: .grid, style: .runeArt)
        XCTAssertGreaterThan(grid, qwerty)
    }

    /// The hinted face carries a small Latin letter under each glyph, so its keys — and
    /// only its keys — are the tall variant.
    func testOnlyTheHintedFaceGetsTheTallKeys() {
        XCTAssertEqual(
            KeyboardMetrics.keyHeight(style: .runeArt),
            KeyboardMetrics.baseKeyHeight
        )
        XCTAssertEqual(
            KeyboardMetrics.keyHeight(style: .runeHints),
            KeyboardMetrics.hintedKeyHeight
        )
        XCTAssertEqual(
            KeyboardMetrics.keyHeight(style: .letters),
            KeyboardMetrics.baseKeyHeight
        )
    }

    /// Pins the composition: padding + rows + gap + bottom bar + padding.
    func testContentHeightMatchesExplicitArithmetic() {
        let height = KeyboardMetrics.contentHeight(page: .letters, mode: .qwerty, style: .runeArt)
        let rows: CGFloat = 3
        let expected = KeyboardMetrics.topPadding
            + (rows * KeyboardMetrics.baseKeyHeight + (rows - 1) * KeyboardMetrics.rowGap)
            + KeyboardMetrics.rowGap
            + KeyboardMetrics.bottomBarHeight(compact: false)
            + KeyboardMetrics.bottomPadding
        XCTAssertEqual(height, expected, accuracy: 0.001)
    }

    /// Landscape shrinks the keys to 32pt; a fixed 42pt bar would tower over them and
    /// invert the size hierarchy between typing keys and chrome.
    func testCompactBottomBarShrinksWithTheKeys() {
        XCTAssertLessThan(
            KeyboardMetrics.bottomBarHeight(compact: true),
            KeyboardMetrics.bottomBarHeight(compact: false)
        )
        XCTAssertGreaterThanOrEqual(
            KeyboardMetrics.bottomBarHeight(compact: true),
            KeyboardMetrics.compactBaseKeyHeight,
            "the bar hosts the widest touch targets; it must not drop below key height"
        )
    }

    func testCompactContentHeightUsesTheCompactBar() {
        let height = KeyboardMetrics.contentHeight(page: .letters, mode: .qwerty, style: .letters, compact: true)
        let expected = KeyboardMetrics.topPadding
            + KeyboardMetrics.pageHeight(page: .letters, mode: .qwerty, style: .letters, compact: true)
            + KeyboardMetrics.rowGap
            + KeyboardMetrics.bottomBarHeight(compact: true)
            + KeyboardMetrics.bottomPadding
        XCTAssertEqual(height, expected, accuracy: 0.001)
    }

    /// The literals the old controller returned. Each one the new derivation exceeds is a
    /// configuration that used to clip.
    func testNewDerivationFixesTheConfigurationsTheOldLiteralsUnderAllocated() {
        // Old landscape branch was taken even in portrait, because it compared the
        // keyboard's own bounds, which are wider than tall in both orientations.
        let oldLandscapeNoHints: CGFloat = 190
        let oldLandscapeHints: CGFloat = 210

        let gridNoHints = KeyboardMetrics.contentHeight(page: .letters, mode: .grid, style: .runeArt)
        let gridHints = KeyboardMetrics.contentHeight(page: .letters, mode: .grid, style: .runeHints)

        XCTAssertGreaterThan(gridNoHints, oldLandscapeNoHints)
        XCTAssertGreaterThan(gridHints, oldLandscapeHints)
    }

    func testCompactKeysAreShorterButStillPositive() {
        for style in allStyles {
            let regular = KeyboardMetrics.keyHeight(style: style, compact: false)
            let compact = KeyboardMetrics.keyHeight(style: style, compact: true)
            XCTAssertLessThan(compact, regular)
            XCTAssertGreaterThan(compact, 0)
        }
    }

    /// Ten keys plus their nine gaps must fit the width they were derived from.
    func testKeyUnitTilesTheAvailableWidth() {
        for width in [320.0, 375.0, 390.0, 430.0, 768.0] as [CGFloat] {
            let unit = KeyboardMetrics.keyUnit(availableWidth: width)
            let used = 10 * unit + 9 * KeyboardMetrics.keyGap
            XCTAssertEqual(used, width, accuracy: 0.001, "key unit must tile width \(width)")
            XCTAssertGreaterThan(unit, 0)
        }
    }

    func testKeyUnitClampsAtZeroForDegenerateWidth() {
        XCTAssertEqual(KeyboardMetrics.keyUnit(availableWidth: 0), 0)
        XCTAssertEqual(KeyboardMetrics.keyUnit(availableWidth: -50), 0)
    }

    /// Function keys must clear the 44pt minimum touch target.
    func testFunctionKeyWidthMeetsMinimumTouchTarget() {
        XCTAssertGreaterThanOrEqual(KeyboardMetrics.functionKeyWidth, 44)
    }
}
