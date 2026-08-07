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

    /// The grid layout still renders a dedicated shift/backspace row that the old
    /// literal table never counted — that undercount was the original bug. The symbol
    /// pages no longer do: delete moved inline onto row three, the way stock lays it
    /// out, which is what stopped the keyboard growing 46pt on every tap of 123.
    func testGridCarriesOneMoreRowThanQwertyAndSymbolsDoNot() {
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .letters, mode: .qwerty), 3)
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .letters, mode: .grid), 4)
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .symbols, mode: .qwerty), 3)
        XCTAssertEqual(KeyboardMetrics.rowCount(page: .symbols, mode: .grid), 3)
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

    /// Pins the composition: padding + suggestion bar + gap + rows + gap + bottom bar
    /// + padding. The suggestion strip is reserved unconditionally, so it belongs in the
    /// arithmetic rather than appearing only when a correction exists.
    func testContentHeightMatchesExplicitArithmetic() {
        let height = KeyboardMetrics.contentHeight(page: .letters, mode: .qwerty, style: .runeArt)
        let rows: CGFloat = 3
        let expected = KeyboardMetrics.topPadding
            + KeyboardMetrics.suggestionBarHeight(compact: false)
            + KeyboardMetrics.rowGap()
            + (rows * KeyboardMetrics.baseKeyHeight + (rows - 1) * KeyboardMetrics.rowGap())
            + KeyboardMetrics.rowGap()
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
            + KeyboardMetrics.suggestionBarHeight(compact: true)
            + KeyboardMetrics.rowGap(compact: true)
            + KeyboardMetrics.pageHeight(page: .letters, mode: .qwerty, style: .letters, compact: true)
            + KeyboardMetrics.rowGap(compact: true)
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

    /// Chrome that is not part of the letter grid must clear the 44pt touch target.
    func testMinimumTouchTargetMeetsTheGuideline() {
        XCTAssertGreaterThanOrEqual(KeyboardMetrics.minimumTouchTarget, 44)
    }

    /// The function row has to tile exactly the width the row above it tiles, or the
    /// letter block drifts off the columns and glide decoding drifts with it:
    ///
    ///     shift + flank + 7 keys + 6 gaps + flank + delete == 10 keys + 9 gaps
    ///
    /// This is the identity stock's own row three satisfies, and it is what sizes
    /// `functionKeyWidth` — so if either it or `functionKeyFlank` is retuned by hand,
    /// this test is what notices.
    func testFunctionRowTilesTheSameWidthAsTheTopRow() {
        for width in [375.0, 390.0, 402.0, 420.0, 440.0] as [CGFloat] {
            let unit = KeyboardMetrics.keyUnit(availableWidth: width)
            let function = KeyboardMetrics.functionKeyWidth(keyUnit: unit)
            let flank = KeyboardMetrics.functionKeyFlank(keyUnit: unit)
            let functionRow = 2 * function
                + 2 * flank
                + 7 * unit
                + 6 * KeyboardMetrics.keyGap
            XCTAssertEqual(functionRow, width, accuracy: 0.001,
                           "function row must tile width \(width)")
        }
    }

    /// The spacer a row inserts beside a function key, plus the two gaps the layout
    /// already contributes, must come to the flank — otherwise the drawn row and the
    /// arithmetic above disagree about where Z starts.
    func testFunctionKeySpacerCompletesTheFlank() {
        for width in [375.0, 390.0, 402.0, 420.0, 440.0] as [CGFloat] {
            let unit = KeyboardMetrics.keyUnit(availableWidth: width)
            let spacer = KeyboardMetrics.functionKeySpacer(keyUnit: unit)
            XCTAssertEqual(spacer + 2 * KeyboardMetrics.keyGap,
                           KeyboardMetrics.functionKeyFlank(keyUnit: unit),
                           accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(spacer, 0)
        }
    }

    /// The stock iOS 26 English keyboard, measured off native-scale screenshots on four
    /// iPhone widths. These are the numbers the whole spacing scale exists to match, so
    /// they are asserted directly rather than left to a comment: a keyboard extension
    /// inherits its muscle memory from the system keyboard, and a drift here is a drift
    /// under someone's thumb.
    func testGeometryMatchesTheMeasuredStockKeyboard() {
        XCTAssertEqual(KeyboardMetrics.edgeInset, 6.5)
        XCTAssertEqual(KeyboardMetrics.keyGap, 6)
        XCTAssertEqual(KeyboardMetrics.rowGap(), 11)
        XCTAssertEqual(KeyboardMetrics.rowGap(compact: true), 8)
        XCTAssertEqual(KeyboardMetrics.baseKeyHeight, 43)
        XCTAssertEqual(KeyboardMetrics.compactBaseKeyHeight, 27.5)
        // Stock's bottom row is a key row, not chrome: same height, same gap above it.
        XCTAssertEqual(KeyboardMetrics.bottomBarHeight(), KeyboardMetrics.baseKeyHeight)

        // Key width and the row-three function width, on the two commonest iPhone
        // widths, against what the screenshots measured.
        for (width, keyWidth, functionWidth) in [
            (390.0, 32.3, 44.3), (402.0, 33.5, 45.5)
        ] as [(CGFloat, CGFloat, CGFloat)] {
            let unit = KeyboardMetrics.keyUnit(availableWidth: width - 2 * KeyboardMetrics.edgeInset)
            XCTAssertEqual(unit, keyWidth, accuracy: 0.05, "key width at \(width)pt")
            XCTAssertEqual(KeyboardMetrics.functionKeyWidth(keyUnit: unit), functionWidth,
                           accuracy: 0.05, "function key width at \(width)pt")
        }
    }

    /// Row pitch — key height plus the gap under it — is what a thumb actually
    /// remembers, and it is where ours was most wrong: 46pt against stock's 54 put the
    /// third row 16pt off its remembered target. Stock measures 54pt portrait and 35.5pt
    /// landscape; the horizontal pitch is the key unit plus one gap and tiles by
    /// construction (see testKeyUnitTilesTheAvailableWidth).
    func testRowPitchMatchesStock() {
        XCTAssertEqual(
            KeyboardMetrics.baseKeyHeight + KeyboardMetrics.rowGap(),
            54,
            accuracy: 0.001
        )
        XCTAssertEqual(
            KeyboardMetrics.compactBaseKeyHeight + KeyboardMetrics.rowGap(compact: true),
            35.5,
            accuracy: 0.001
        )
    }
}
