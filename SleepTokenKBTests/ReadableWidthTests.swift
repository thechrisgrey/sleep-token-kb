import SwiftUI
import XCTest
@testable import SleepTokenKB

/// The app ships to iPad (`TARGETED_DEVICE_FAMILY: "1,2"`) with all four iPad
/// orientations declared, but every host-app screen was a single-column ScrollView with
/// no size-class layer — so a 13" iPad rendered a stretched phone layout with card prose
/// running far past a readable measure. This pins the cap that fixes it.
///
/// The rule is driven by size class, never by device model, so iPad Split View and Slide
/// Over (which hand a tablet a phone-width window) get the right answer for free.
final class ReadableWidthTests: XCTestCase {

    /// A regular width is an iPad, a wide Split View column, or a Max phone in
    /// landscape — the cases where an uncapped column becomes unreadable.
    func testRegularWidthGetsCapped() {
        XCTAssertEqual(Theme.contentWidth(for: .regular), Theme.readableWidth)
    }

    /// Compact width is every iPhone in portrait and a narrow multitasking column.
    /// Capping there would waste horizontal space the layout needs.
    func testCompactWidthIsUncapped() {
        XCTAssertNil(Theme.contentWidth(for: .compact))
    }

    /// SwiftUI reports no size class in some contexts; the safe answer is the phone
    /// behaviour, not an arbitrary cap.
    func testUnknownSizeClassIsUncapped() {
        XCTAssertNil(Theme.contentWidth(for: nil))
    }

    /// A measure this wide is the point of the cap. Much narrower wastes an iPad;
    /// much wider stops being a readable column at body size.
    func testCapStaysInAReadableRange() {
        XCTAssertGreaterThanOrEqual(Theme.readableWidth, 480)
        XCTAssertLessThanOrEqual(Theme.readableWidth, 760)
    }
}
