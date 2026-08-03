import Foundation

/// Sleep Token ritual alphabet: Latin letter ↔ key art asset.
public enum SleepTokenLetter: String, CaseIterable, Identifiable, Codable, Sendable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z

    public var id: String { rawValue }

    public var latin: String { rawValue }
    public var upperLatin: String { rawValue.uppercased() }

    public var runeIndex: Int {
        Int(rawValue.utf8.first! - UInt8(ascii: "a"))
    }

    /// Exact custom-font codepoint for Rune Pad (U+E900…).
    public static let puaBase = 0xE900

    public var exactRuneCharacter: Character {
        Character(UnicodeScalar(Self.puaBase + runeIndex)!)
    }

    public var exactRuneString: String { String(exactRuneCharacter) }

    public var assetName: String { "symbol_\(rawValue)" }

    /// Map a Private Use rune character back to its letter (for asset rendering).
    public static func fromRuneCharacter(_ character: Character) -> SleepTokenLetter? {
        guard let value = character.unicodeScalars.first?.value,
              value >= UInt32(puaBase),
              value < UInt32(puaBase + 26) else {
            return nil
        }
        return SleepTokenLetter.allCases[Int(value - UInt32(puaBase))]
    }

    public var glyphDescription: String {
        switch self {
        case .a: "Circle with center dot and X base"
        case .b: "Diamond with horizontal midline"
        case .c: "Diamond, bottom half filled"
        case .d: "Diamond, top half filled"
        case .e: "Horizontal bar with inverted chevron"
        case .f: "Diamond, left half filled"
        case .g: "Diamond with center dot"
        case .h: "Diamond with X and center dot"
        case .i: "Left chevron with center dot"
        case .j: "Right arrow with leading dot"
        case .k: "Right arrow with X and leading dot"
        case .l: "X with lower-right arm and trailing dot"
        case .m: "Peak with X and base center dot"
        case .n: "V with X and apex dot"
        case .o: "Double vertical arches"
        case .p: "Triple vertical arches"
        case .q: "Open square with center dot"
        case .r: "Closed square with center dot"
        case .s: "Diamond, bottom filled, X on top"
        case .t: "Diamond, top filled, X below"
        case .u: "Concentric circles with center"
        case .v: "Circle with center and X above"
        case .w: "Open diamond"
        case .x: "Horizontal bar"
        case .y: "Diamond, right half filled"
        case .z: "Horizontal bar with Y below"
        }
    }

    /// Keyboard always inserts normal English (works in every app).
    public func englishInsert(shifted: Bool) -> String {
        shifted ? upperLatin : latin
    }

    /// What VoiceOver speaks for a letter key: the case the next insert will actually
    /// produce, in stock's phrasing — "a" against "capital A". Autocapitalization arms
    /// and releases shift silently, so the case cue has to be audible per key, not only
    /// as the shift key's value.
    public func spokenKeyName(uppercase: Bool) -> String {
        uppercase ? "capital \(upperLatin)" : latin
    }

    /// Latin reading of a Rune Pad string: Private Use rune characters map back to
    /// their letters, everything else (spaces, punctuation) passes through unchanged.
    /// Lowercase, so callers can spell-check it directly and style case themselves.
    public static func latinTranslation(of text: String) -> String {
        String(text.map { character in
            fromRuneCharacter(character)?.latin.first ?? character
        })
    }
}

public enum KeyboardLayout {
    public static let qwertyRows: [[SleepTokenLetter]] = [
        [.q, .w, .e, .r, .t, .y, .u, .i, .o, .p],
        [.a, .s, .d, .f, .g, .h, .j, .k, .l],
        [.z, .x, .c, .v, .b, .n, .m]
    ]

    public static let gridRows: [[SleepTokenLetter]] = [
        [.a, .b, .c, .d, .e, .f, .g, .h, .i],
        [.j, .k, .l, .m, .n, .o, .p, .q, .r],
        [.s, .t, .u, .v, .w, .x, .y, .z]
    ]

    /// Digits and punctuation for the 123 page. Lives here beside the letter tables so
    /// all key layouts are in one place and reachable from the test target.
    ///
    /// Row three is deliberately short. Stock flanks it with the page-switch key and
    /// delete; ours used to run ten keys wide and push delete onto a row of its own,
    /// which is what made the keyboard grow 46pt whenever you tapped 123.
    public static let symbolRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""],
        [".", ",", "?", "!", "'"]
    ]

    /// The #+= page. The five characters that used to share row three of the 123 page
    /// (`# % * + =`) live here, joined by the brackets and math symbols stock offers and
    /// we did not — so the split adds characters rather than losing any.
    public static let symbolAltRows: [[String]] = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"],
        [".", ",", "?", "!", "'"]
    ]
}
