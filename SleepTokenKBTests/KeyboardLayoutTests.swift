import XCTest
@testable import SleepTokenKB

/// The three key tables were previously verified only by eye. A missing or duplicated
/// letter would render a keyboard that silently cannot type it.
final class KeyboardLayoutTests: XCTestCase {

    private func assertCoversAlphabet(
        _ rows: [[SleepTokenLetter]],
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let flat = rows.flatMap { $0 }
        // The pair catches both a missing letter and a duplicated one.
        XCTAssertEqual(Set(flat), Set(SleepTokenLetter.allCases), "\(name) must contain every letter", file: file, line: line)
        XCTAssertEqual(flat.count, 26, "\(name) must contain each letter exactly once", file: file, line: line)
        XCTAssertTrue(rows.allSatisfy { !$0.isEmpty }, "\(name) must have no empty rows", file: file, line: line)
    }

    func testQwertyRowsCoverAlphabetExactlyOnce() {
        assertCoversAlphabet(KeyboardLayout.qwertyRows, "qwertyRows")
    }

    func testGridRowsCoverAlphabetExactlyOnce() {
        assertCoversAlphabet(KeyboardLayout.gridRows, "gridRows")
    }

    /// LetterPage places shift and backspace on the last row and insets the second-to-last.
    /// KeyboardMetrics counts rows to reserve height. Both assume three rows per layout.
    func testRowCountsAreThreeForBothLayouts() {
        XCTAssertEqual(KeyboardLayout.qwertyRows.count, 3)
        XCTAssertEqual(KeyboardLayout.gridRows.count, 3)
    }

    /// The widest row drives the shared key unit, so nothing may exceed 10 keys.
    func testNoRowExceedsTenKeys() {
        for row in KeyboardLayout.qwertyRows + KeyboardLayout.gridRows {
            XCTAssertLessThanOrEqual(row.count, 10)
        }
        XCTAssertEqual(KeyboardLayout.qwertyRows.first?.count, 10, "top row defines the key unit")
    }

    func testSymbolRowsHaveNoDuplicates() {
        let flat = KeyboardLayout.symbolRows.flatMap { $0 }
        // ForEach(id: \.self) over these requires uniqueness.
        XCTAssertEqual(Set(flat).count, flat.count, "symbol keys must be unique for ForEach(id: \\.self)")
        XCTAssertEqual(flat.count, 30)
        XCTAssertTrue(KeyboardLayout.symbolRows.allSatisfy { !$0.isEmpty })
        XCTAssertEqual(KeyboardLayout.symbolRows.count, 3)
    }
}
