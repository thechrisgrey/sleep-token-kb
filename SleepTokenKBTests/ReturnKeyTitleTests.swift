import XCTest
import UIKit
@testable import SleepTokenKB

/// The return key previously read "return" in every context, including Search and Send
/// fields. `UIReturnKeyType` is not `CaseIterable`, so the full list is spelled out here —
/// which is also what makes the "every case has a title" guard meaningful.
final class ReturnKeyTitleTests: XCTestCase {

    private let allTypes: [UIReturnKeyType] = [
        .default, .go, .google, .join, .next, .route,
        .search, .send, .yahoo, .done, .emergencyCall, .continue
    ]

    /// Lowercase on purpose: it is what the system keyboard draws, and the cap sits beside
    /// "space", which is also lowercase.
    func testDefaultReadsAsLowercaseReturn() {
        XCTAssertEqual(ReturnKeyTitle.title(for: .default), "return")
    }

    func testSearchFieldsReadAsSearch() {
        XCTAssertEqual(ReturnKeyTitle.title(for: .search), "Search")
    }

    /// google and yahoo are legacy spellings of "this is a search field"; neither should
    /// put a brand name on the keycap.
    func testLegacySearchTypesAlsoReadAsSearch() {
        XCTAssertEqual(ReturnKeyTitle.title(for: .google), "Search")
        XCTAssertEqual(ReturnKeyTitle.title(for: .yahoo), "Search")
    }

    func testTheCommonActionsHaveTheirOwnTitles() {
        XCTAssertEqual(ReturnKeyTitle.title(for: .send), "Send")
        XCTAssertEqual(ReturnKeyTitle.title(for: .done), "Done")
        XCTAssertEqual(ReturnKeyTitle.title(for: .go), "Go")
        XCTAssertEqual(ReturnKeyTitle.title(for: .next), "Next")
        XCTAssertEqual(ReturnKeyTitle.title(for: .join), "Join")
        XCTAssertEqual(ReturnKeyTitle.title(for: .route), "Route")
        XCTAssertEqual(ReturnKeyTitle.title(for: .continue), "Continue")
    }

    func testEveryTypeProducesANonEmptyTitle() {
        for type in allTypes {
            XCTAssertFalse(
                ReturnKeyTitle.title(for: type).isEmpty,
                "return key type \(type.rawValue) has no title"
            )
        }
    }

    /// The keycap is 56pt wide and draws at 13pt with a 0.65 minimum scale factor, so an
    /// over-long title is the one thing that truncates instead of shrinking to fit.
    func testNoTitleIsTooLongForTheKeycap() {
        for type in allTypes {
            XCTAssertLessThanOrEqual(
                ReturnKeyTitle.title(for: type).count, 9,
                "\(ReturnKeyTitle.title(for: type)) will not fit the return keycap"
            )
        }
    }

    /// VoiceOver reads the label, not the cap. "return" as a bare lowercase word is the one
    /// title that needs promoting for speech.
    func testVoiceOverAnnouncesTheDefaultAsAProperWord() {
        XCTAssertEqual(ReturnKeyTitle.accessibilityLabel(for: .default), "Return")
    }

    func testVoiceOverOtherwiseMatchesTheVisibleTitle() {
        for type in allTypes where type != .default {
            XCTAssertEqual(
                ReturnKeyTitle.accessibilityLabel(for: type),
                ReturnKeyTitle.title(for: type),
                "the spoken label should match the cap for \(type.rawValue)"
            )
        }
    }

    func testEveryTypeProducesANonEmptyAccessibilityLabel() {
        for type in allTypes {
            XCTAssertFalse(ReturnKeyTitle.accessibilityLabel(for: type).isEmpty)
        }
    }
}
