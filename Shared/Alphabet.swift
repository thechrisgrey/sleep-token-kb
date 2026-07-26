import Foundation

/// Sleep Token ritual alphabet: Latin letter ↔ symbol asset.
public enum SleepTokenLetter: String, CaseIterable, Identifiable, Codable, Sendable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z

    public var id: String { rawValue }

    /// Character inserted into the text field (always Latin).
    public var latin: String { rawValue }

    public var upperLatin: String { rawValue.uppercased() }

    /// Asset catalog name (template, monochrome).
    public var assetName: String { "symbol_\(rawValue)" }

    /// Short description of the glyph (for accessibility / host chart).
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
}

/// QWERTY rows (lowercase); shift is handled at insert time.
public enum KeyboardLayout {
    public static let qwertyRows: [[SleepTokenLetter]] = [
        [.q, .w, .e, .r, .t, .y, .u, .i, .o, .p],
        [.a, .s, .d, .f, .g, .h, .j, .k, .l],
        [.z, .x, .c, .v, .b, .n, .m]
    ]

    /// A–Z grid: 3 rows of 9 + remainder (classic learning layout).
    public static let gridRows: [[SleepTokenLetter]] = [
        [.a, .b, .c, .d, .e, .f, .g, .h, .i],
        [.j, .k, .l, .m, .n, .o, .p, .q, .r],
        [.s, .t, .u, .v, .w, .x, .y, .z]
    ]
}
