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
        XCTAssertEqual(ReturnKeyTitle.title(for: .search), "search")
    }

    /// google and yahoo are legacy spellings of "this is a search field"; neither should
    /// put a brand name on the keycap.
    func testLegacySearchTypesAlsoReadAsSearch() {
        XCTAssertEqual(ReturnKeyTitle.title(for: .google), "search")
        XCTAssertEqual(ReturnKeyTitle.title(for: .yahoo), "search")
    }

    /// Lowercase like the default: since iOS 13 the stock English keyboard draws every
    /// action title in lowercase, and a capitalised "Send" beside a lowercase "space"
    /// was the one cap on the bar that did not match its neighbours.
    func testTheCommonActionsHaveTheirOwnLowercaseTitles() {
        XCTAssertEqual(ReturnKeyTitle.title(for: .send), "send")
        XCTAssertEqual(ReturnKeyTitle.title(for: .done), "done")
        XCTAssertEqual(ReturnKeyTitle.title(for: .go), "go")
        XCTAssertEqual(ReturnKeyTitle.title(for: .next), "next")
        XCTAssertEqual(ReturnKeyTitle.title(for: .join), "join")
        XCTAssertEqual(ReturnKeyTitle.title(for: .route), "route")
        XCTAssertEqual(ReturnKeyTitle.title(for: .continue), "continue")
    }

    func testEveryTitleIsLowercase() {
        for type in allTypes {
            let title = ReturnKeyTitle.title(for: type)
            XCTAssertEqual(title, title.lowercased(), "\(title) should be lowercase like stock's caps")
        }
    }

    func testEveryTypeProducesANonEmptyTitle() {
        for type in allTypes {
            XCTAssertFalse(
                ReturnKeyTitle.title(for: type).isEmpty,
                "return key type \(type.rawValue) has no title"
            )
        }
    }

    /// The keycap is 64pt wide and draws at 13pt with a minimum scale factor, so an
    /// over-long title is the one thing that truncates instead of shrinking to fit.
    /// KeyboardMetricsTests measures the real fit at the Dynamic Type ceiling.
    func testNoTitleIsTooLongForTheKeycap() {
        for type in allTypes {
            XCTAssertLessThanOrEqual(
                ReturnKeyTitle.title(for: type).count, 9,
                "\(ReturnKeyTitle.title(for: type)) will not fit the return keycap"
            )
        }
    }

    // MARK: - Action keys

    /// Stock paints the return key as a tinted action key with a white title for the
    /// field actions, and leaves it function-grey for a plain return and for "next".
    func testTheFieldActionsAreActionKeys() {
        for type in [UIReturnKeyType.go, .google, .yahoo, .search, .send, .done, .join, .route, .continue] {
            XCTAssertTrue(ReturnKeyTitle.isAction(for: type), "\(type.rawValue) should be an action key")
        }
    }

    func testReturnNextAndEmergencyStayFunctionKeys() {
        for type in [UIReturnKeyType.default, .next, .emergencyCall] {
            XCTAssertFalse(ReturnKeyTitle.isAction(for: type), "\(type.rawValue) should stay a function key")
        }
    }

    // MARK: - VoiceOver

    /// VoiceOver reads the label, not the cap. The caps are lowercase to match stock;
    /// the spoken label carries the capital.
    func testVoiceOverAnnouncesTheDefaultAsAProperWord() {
        XCTAssertEqual(ReturnKeyTitle.accessibilityLabel(for: .default), "Return")
    }

    func testVoiceOverOtherwiseSpeaksTheCapitalisedTitle() {
        for type in allTypes where type != .default {
            XCTAssertEqual(
                ReturnKeyTitle.accessibilityLabel(for: type),
                ReturnKeyTitle.title(for: type).capitalized,
                "the spoken label should be the cap, capitalised, for \(type.rawValue)"
            )
        }
    }

    func testEveryTypeProducesANonEmptyAccessibilityLabel() {
        for type in allTypes {
            XCTAssertFalse(ReturnKeyTitle.accessibilityLabel(for: type).isEmpty)
        }
    }
}
