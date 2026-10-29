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

// MARK: - Landing tab

/// Which tab the page opens on. Stock opens on Recents once there are any, and on
/// Smileys before: a new user who taps the emoji key should see emoji, not the
/// clock tab's teaching text.
extension EmojiCatalogTests {

    func testThePageLandsOnRecentsOnceThereAreAny() {
        XCTAssertEqual(EmojiCategory.landing(recentsEmpty: false), .recents)
    }

    func testThePageLandsOnSmileysUntilAnEmojiHasBeenUsed() {
        XCTAssertEqual(EmojiCategory.landing(recentsEmpty: true), .smileys)
    }
}

// MARK: - Per-entry invariants

/// What every catalog entry has to be for the grid, the recents list and the document
/// to agree on it: one character, and — where Unicode leaves the choice open — the
/// emoji-presentation form stock inserts, so a bare U+1F590 beside a qualified "✌️"
/// cannot render as a text glyph on a non-Apple recipient.
extension EmojiCatalogTests {

    private var everyAuthoredEntry: [(EmojiCategory, String)] {
        EmojiCategory.allCases
            .filter { $0 != .recents }
            .flatMap { category in EmojiCatalog.emoji(in: category).map { (category, $0) } }
    }

    func testEveryEntryIsExactlyOneCharacter() {
        for (category, emoji) in everyAuthoredEntry {
            XCTAssertEqual(
                emoji.count, 1,
                "\(emoji) in \(category.rawValue) is \(emoji.count) characters, not one"
            )
        }
    }

    /// A scalar whose default presentation is text (`isEmoji` without
    /// `isEmojiPresentation`) must carry U+FE0F somewhere in the sequence, or be part
    /// of a sequence — a flag, a keycap, a ZWJ family — that is emoji by construction.
    func testTextDefaultScalarsAreFullyQualified() {
        for (category, emoji) in everyAuthoredEntry {
            guard let first = emoji.unicodeScalars.first,
                  first.properties.isEmoji, !first.properties.isEmojiPresentation
            else { continue }
            XCTAssertTrue(
                emoji.unicodeScalars.contains("\u{FE0F}"),
                "\(emoji) (\(first.debugDescription)) in \(category.rawValue) is a text-default scalar with no U+FE0F"
            )
        }
    }
}
