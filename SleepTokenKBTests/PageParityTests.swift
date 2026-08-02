import XCTest
@testable import SleepTokenKB

/// Stock iOS keeps the keyboard exactly the same height whichever page is showing, and
/// puts delete inline on the third row of the 123 page rather than on a row of its own.
/// We did neither: tapping 123 grew the keyboard by 46pt because the symbols page was
/// budgeted a fourth row for a lone delete key.
final class PageParityTests: XCTestCase {

    // MARK: - Pages

    func testFourPagesExist() {
        XCTAssertEqual(
            Set(KeyboardMetrics.Page.allCases),
            [.letters, .symbols, .symbolsAlt, .emoji]
        )
    }

    /// Delete now sits on row three, so the symbols page is three rows like stock —
    /// not three plus a delete row.
    func testSymbolPagesAreThreeRows() {
        for mode in LayoutMode.allCases {
            XCTAssertEqual(KeyboardMetrics.rowCount(page: .symbols, mode: mode), 3)
            XCTAssertEqual(KeyboardMetrics.rowCount(page: .symbolsAlt, mode: mode), 3)
        }
    }

    // MARK: - Constant height

    /// The whole point: switching pages must not resize the input view.
    func testReservedHeightIsIdenticalForEveryPage() {
        for mode in LayoutMode.allCases {
            for compact in [false, true] {
                let reserved = KeyboardMetrics.reservedHeight(mode: mode, compact: compact)
                for page in KeyboardMetrics.Page.allCases {
                    for style in KeyFaceStyle.allCases {
                        let content = KeyboardMetrics.contentHeight(
                            page: page, mode: mode, style: style, compact: compact
                        )
                        XCTAssertLessThanOrEqual(
                            content, reserved,
                            "\(page)/\(mode)/\(style)/compact=\(compact) overflows its reservation"
                        )
                    }
                }
            }
        }
    }

    /// Reserved height depends only on the layout and the size class — never on the page
    /// or the key face, both of which the user can change mid-session.
    func testReservedHeightDoesNotVaryWithPageOrFace() {
        for mode in LayoutMode.allCases {
            let heights = Set(
                [false, true].map { KeyboardMetrics.reservedHeight(mode: mode, compact: $0) }
            )
            XCTAssertEqual(heights.count, 2, "compact and regular should differ")
        }
    }

    /// A key face only changes letter keycaps, so it must not resize a symbol or emoji
    /// page — that was one of the sources of the height jump.
    func testKeyFaceDoesNotChangeNonLetterPageHeight() {
        for page in [KeyboardMetrics.Page.symbols, .symbolsAlt, .emoji] {
            for mode in LayoutMode.allCases {
                let heights = Set(KeyFaceStyle.allCases.map {
                    KeyboardMetrics.contentHeight(page: page, mode: mode, style: $0)
                })
                XCTAssertEqual(heights.count, 1, "\(page) height varies with key face")
            }
        }
    }

    // MARK: - Symbol coverage

    /// Splitting the old 30-character symbol row set across two stock-shaped pages must
    /// not drop a single character the keyboard could previously type.
    func testNoSymbolWasLostInTheSplit() {
        let previouslyTypeable: Set<String> = [
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
            "-", "/", ":", ";", "(", ")", "$", "&", "@", "\"",
            ".", ",", "?", "!", "'", "#", "%", "*", "+", "=",
        ]
        let now = Set(
            (KeyboardLayout.symbolRows + KeyboardLayout.symbolAltRows).flatMap { $0 }
        )
        XCTAssertTrue(
            previouslyTypeable.isSubset(of: now),
            "lost: \(previouslyTypeable.subtracting(now).sorted())"
        )
    }

    /// Stock repeats `. , ? ! '` on both symbol pages so the common punctuation is
    /// always one tap away.
    func testCommonPunctuationIsOnBothSymbolPages() {
        let shared: Set<String> = [".", ",", "?", "!", "'"]
        XCTAssertTrue(shared.isSubset(of: Set(KeyboardLayout.symbolRows.flatMap { $0 })))
        XCTAssertTrue(shared.isSubset(of: Set(KeyboardLayout.symbolAltRows.flatMap { $0 })))
    }

    /// Row three leaves room for the page-switch key and delete that flank it, so it
    /// must stay short. Ten keys plus both is what forced delete onto its own row.
    func testSymbolRowThreeIsShortEnoughForInlineDelete() {
        XCTAssertLessThanOrEqual(KeyboardLayout.symbolRows[2].count, 6)
        XCTAssertLessThanOrEqual(KeyboardLayout.symbolAltRows[2].count, 6)
    }

    func testSymbolPagesHaveFullTopRows() {
        for rows in [KeyboardLayout.symbolRows, KeyboardLayout.symbolAltRows] {
            XCTAssertEqual(rows.count, 3)
            XCTAssertEqual(rows[0].count, 10)
            XCTAssertEqual(rows[1].count, 10)
        }
    }
}
