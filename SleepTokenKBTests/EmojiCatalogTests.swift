import XCTest
@testable import SleepTokenKB

/// iOS vends no emoji catalog to third-party keyboards, so this table is ours. These
/// tests pin the properties a keyboard actually depends on: stable category order,
/// no duplicates across categories, and a recents list that behaves like stock
/// (most-recent-first, no repeats, bounded).
final class EmojiCatalogTests: XCTestCase {

    /// Recents starts empty by design; every authored category must not.
    func testEveryAuthoredCategoryHasEmoji() {
        for category in EmojiCategory.allCases where category != .recents {
            XCTAssertFalse(
                EmojiCatalog.emoji(in: category).isEmpty,
                "\(category.rawValue) is empty"
            )
        }
    }

    /// The category strip is rendered from `allCases`, so the order is the UI order.
    /// Recents must come first, the way stock puts the clock tab first.
    func testRecentsIsTheFirstCategory() {
        XCTAssertEqual(EmojiCategory.allCases.first, .recents)
    }

    /// A duplicate would show the same emoji under two tabs and make recents ambiguous.
    func testNoEmojiAppearsInTwoCategories() {
        var seen: [String: EmojiCategory] = [:]
        for category in EmojiCategory.allCases where category != .recents {
            for emoji in EmojiCatalog.emoji(in: category) {
                if let first = seen[emoji] {
                    XCTFail("\(emoji) appears in both \(first.rawValue) and \(category.rawValue)")
                }
                seen[emoji] = category
            }
        }
    }

    func testEveryCategoryHasAnAccessibilityLabel() {
        for category in EmojiCategory.allCases {
            XCTAssertFalse(category.accessibilityLabel.isEmpty)
            XCTAssertFalse(category.symbolName.isEmpty)
        }
    }

    // MARK: - Recents

    func testRecordingPutsMostRecentFirst() {
        let recents = EmojiCatalog.recents(after: "🙂", in: ["😀", "😅"])
        XCTAssertEqual(recents, ["🙂", "😀", "😅"])
    }

    /// Re-picking an emoji must move it to the front, not add a second copy.
    func testRecordingAnExistingEmojiMovesItWithoutDuplicating() {
        let recents = EmojiCatalog.recents(after: "😅", in: ["😀", "😅", "🙂"])
        XCTAssertEqual(recents, ["😅", "😀", "🙂"])
    }

    func testRecentsAreBounded() {
        var recents: [String] = []
        for emoji in EmojiCatalog.emoji(in: .smileys).prefix(EmojiCatalog.recentsLimit + 10) {
            recents = EmojiCatalog.recents(after: emoji, in: recents)
        }
        XCTAssertEqual(recents.count, EmojiCatalog.recentsLimit)
    }

    /// The oldest entry is the one that falls off the end.
    func testOldestRecentIsEvicted() {
        let full = Array(EmojiCatalog.emoji(in: .smileys).prefix(EmojiCatalog.recentsLimit))
        let oldest = full.last!
        let updated = EmojiCatalog.recents(after: "🫥", in: full)
        XCTAssertEqual(updated.count, EmojiCatalog.recentsLimit)
        XCTAssertFalse(updated.contains(oldest))
        XCTAssertEqual(updated.first, "🫥")
    }
}
