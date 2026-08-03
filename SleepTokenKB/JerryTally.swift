import Foundation

/// The hunt's count, written out — "Four of ten" — with no names, no locations,
/// and nothing at all before the first find. The words match the register the
/// enable guide's roman numerals set: ceremony over digits.
enum JerryTally {
    struct Presentation: Equatable {
        let text: String
        let showsReplay: Bool
    }

    private static let words = [
        "zero", "one", "two", "three", "four", "five",
        "six", "seven", "eight", "nine", "ten",
    ]

    static func presentation(found: Int, total: Int) -> Presentation? {
        guard found > 0 else { return nil }
        return Presentation(
            text: "\(word(for: found).capitalized) of \(word(for: total))",
            showsReplay: found >= total
        )
    }

    private static func word(for count: Int) -> String {
        count < words.count ? words[count] : "\(count)"
    }
}
