import XCTest
@testable import SleepTokenKB

/// The decoder's idea of where a key sits must be the rendered truth. These tests
/// re-derive LetterPage's layout arithmetic independently; if either side drifts,
/// glide decodes against a keyboard that is not on screen.
final class KeyCentersTests: XCTestCase {

    private let widths: [CGFloat] = [320, 384.5, 393, 430]
    private let heights: [CGFloat] = [40, 44, 32, 36]

    func testTopRowMatchesLetterPageMath() {
        for width in widths {
            for keyHeight in heights {
                let unit = KeyboardMetrics.keyUnit(availableWidth: width)
                let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: keyHeight)
                for (index, letter) in KeyboardLayout.qwertyRows[0].enumerated() {
                    let expected = CGPoint(
                        x: CGFloat(index) * (unit + KeyboardMetrics.keyGap) + unit / 2,
                        y: keyHeight / 2
                    )
                    XCTAssertEqual(centers[letter]!.x, expected.x, accuracy: 0.001)
                    XCTAssertEqual(centers[letter]!.y, expected.y, accuracy: 0.001)
                }
            }
        }
    }

    func testHomeRowIsInsetByHalfAKey() {
        let width: CGFloat = 393, keyHeight: CGFloat = 40
        let unit = KeyboardMetrics.keyUnit(availableWidth: width)
        let inset = KeyboardMetrics.homeRowInset(keyUnit: unit)
        let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: keyHeight)
        let a = centers[.a]!
        XCTAssertEqual(a.x, inset + unit / 2, accuracy: 0.001)
        XCTAssertEqual(a.y, keyHeight + KeyboardMetrics.rowGap() + keyHeight / 2, accuracy: 0.001)
    }

    /// Shift and backspace flank row three at equal widths, so the seven-letter
    /// block is centered: its midpoint must sit exactly on the page midline.
    func testBottomRowLetterBlockIsCentered() {
        for width in widths {
            let centers = KeyCenters.qwerty(availableWidth: width, keyHeight: 40)
            let mid = (centers[.z]!.x + centers[.m]!.x) / 2
            XCTAssertEqual(mid, width / 2, accuracy: 0.001)
        }
    }

    func testEveryLetterHasACenterAndNeighborsDoNotCollide() {
        let centers = KeyCenters.qwerty(availableWidth: 393, keyHeight: 40)
        XCTAssertEqual(centers.count, 26)
        let unit = KeyboardMetrics.keyUnit(availableWidth: 393)
        XCTAssertEqual(abs(centers[.q]!.x - centers[.w]!.x), unit + KeyboardMetrics.keyGap, accuracy: 0.001)
    }
}
