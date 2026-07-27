import XCTest
@testable import SleepTokenKB

/// Pins the Rune Pad fit arithmetic, in the invariant style of KeyboardMetricsTests:
/// the metrics the fit returns must describe a rendering — INCLUDING the trailing
/// caret the screen appends to the last column — that stays inside the canvas.
/// The caret was exactly the term the fit math once omitted.
final class CanvasMetricsTests: XCTestCase {

    private let canvasSizes: [CGSize] = [
        CGSize(width: 358, height: 260),   // pre-expansion canvas on a 390pt phone
        CGSize(width: 358, height: 520),   // expanded bottom-anchored canvas
        CGSize(width: 288, height: 190)    // SE-class, minimum height
    ]

    private let columnSets: [[String]] = [
        ["ab"],
        ["sleep"],
        ["sleep", "token"],
        ["worship", "arcadia", "euclid"],
        [String(repeating: "a", count: 12)],
        Array(repeating: "abcd", count: 6)
    ]

    /// The invariant: whenever the fit settles above its 8pt floor, the rendered
    /// height of the tallest column WITH the caret, and the rendered width of all
    /// columns, must fit the available area. (At the floor, overflow is possible by
    /// design and the view clips it.)
    func testFittedMetricsIncludingCaretStayWithinTheCanvas() {
        for size in canvasSizes {
            for columns in columnSets {
                let metrics = CanvasMetrics.fitted(
                    columns: columns, in: size, preferredRuneSize: 32
                )
                guard metrics.runeSize > 8.01 else { continue }

                let maxRows = columns.map { max($0.count, 1) }.max() ?? 1
                let availW = max(size.width - metrics.padding * 2, 48)
                let availH = max(size.height - metrics.padding * 2, 48)

                XCTAssertLessThanOrEqual(
                    metrics.renderedColumnHeight(rows: maxRows, includeCaret: true),
                    availH + 0.001,
                    "columns \(columns) in \(size): caret-inclusive height overflows"
                )
                XCTAssertLessThanOrEqual(
                    metrics.renderedWidth(columns: columns.count),
                    availW + 0.001,
                    "columns \(columns) in \(size): width overflows"
                )
            }
        }
    }

    /// Regression for the caret omission: a single column tall enough to be
    /// height-bound must still leave room for its caret at the fitted size.
    func testHeightBoundColumnLeavesRoomForTheCaret() {
        let size = CGSize(width: 358, height: 260)
        let metrics = CanvasMetrics.fitted(
            columns: ["worship"], in: size, preferredRuneSize: 32
        )
        let withCaret = metrics.renderedColumnHeight(rows: 7, includeCaret: true)
        let availH = size.height - metrics.padding * 2
        XCTAssertLessThanOrEqual(withCaret, availH + 0.001)
    }

    func testMoreRowsNeverProducesLargerRunes() {
        let size = CGSize(width: 358, height: 260)
        let short = CanvasMetrics.fitted(columns: ["abc"], in: size, preferredRuneSize: 32)
        let tall = CanvasMetrics.fitted(
            columns: [String(repeating: "a", count: 14)], in: size, preferredRuneSize: 32
        )
        XCTAssertLessThanOrEqual(tall.runeSize, short.runeSize)
    }

    func testRuneSizeNeverFallsBelowTheFloorOrExceedsPreferred() {
        let degenerate = CanvasMetrics.fitted(
            columns: Array(repeating: "aaaaaaaaaa", count: 20),
            in: CGSize(width: 100, height: 100),
            preferredRuneSize: 32
        )
        XCTAssertGreaterThanOrEqual(degenerate.runeSize, 8)

        let roomy = CanvasMetrics.fitted(
            columns: ["a"], in: CGSize(width: 800, height: 800), preferredRuneSize: 32
        )
        XCTAssertLessThanOrEqual(roomy.runeSize, 32)
    }

    /// Pins the single-source derivations both the fit and the renderer consume.
    func testDerivedGeometryConstants() {
        XCTAssertEqual(CanvasMetrics.cell(runeSize: 32), 42)
        XCTAssertEqual(CanvasMetrics.caretHeight(runeSize: 32), 32 * 0.55)
        XCTAssertEqual(CanvasMetrics.caretHeight(runeSize: 10), 8, "caret clamps at 8pt")
        XCTAssertEqual(CanvasMetrics.columnWidth(cell: 42, showChrome: true), 54)
        XCTAssertEqual(CanvasMetrics.columnWidth(cell: 42, showChrome: false), 46)
        XCTAssertEqual(CanvasMetrics.columnVerticalPadding(showChrome: true), 8)
        XCTAssertEqual(CanvasMetrics.columnVerticalPadding(showChrome: false), 2)
    }

    /// Export sizes are a deliberate tier table; pin it.
    func testExportTiersByComplexity() {
        func exportSize(_ columns: [String]) -> CGFloat {
            CanvasMetrics.forExport(columns: columns, preferredRuneSize: 32).runeSize
        }
        XCTAssertEqual(exportSize(["sleep"]), 32)                                   // 5 cells
        XCTAssertEqual(exportSize(["worship", "worship", "worship", "worship", "worship", "worship"]), 26) // 42
        XCTAssertEqual(exportSize(Array(repeating: "worshipful", count: 10)), 20)   // 100
        XCTAssertEqual(exportSize(Array(repeating: "worshipfully", count: 12)), 16) // 144
    }
}
