import Foundation

public enum LayoutMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case qwerty
    case grid

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .qwerty: "QWERTY"
        case .grid: "A–Z Grid"
        }
    }

    public var accessibilityLabel: String {
        switch self {
        case .qwerty: "QWERTY layout"
        case .grid: "A to Z grid layout"
        }
    }

    public var next: LayoutMode {
        switch self {
        case .qwerty: .grid
        case .grid: .qwerty
        }
    }
}

/// How letter keys look. Typing always inserts normal English a–z.
public enum KeyFaceStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Sleep Token art on keys (avid-fan look). Text is still English.
    case runeArt
    /// Plain English A–Z on keys.
    case letters

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .runeArt: "Rune keys"
        case .letters: "ABC keys"
        }
    }

    public var next: KeyFaceStyle {
        switch self {
        case .runeArt: .letters
        case .letters: .runeArt
        }
    }
}

public enum KeyboardPreferences {
    public static let appGroupID = "group.ai.altivum.SleepTokenFanKB"
    public static let layoutModeKey = "layoutMode"
    public static let keyFaceStyleKey = "keyFaceStyle"
    public static let hapticsKey = "hapticsEnabled"
    public static let showLatinHintsKey = "showLatinHints"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static var layoutMode: LayoutMode {
        get {
            guard let raw = defaults.string(forKey: layoutModeKey),
                  let mode = LayoutMode(rawValue: raw) else { return .qwerty }
            return mode
        }
        set { defaults.set(newValue.rawValue, forKey: layoutModeKey) }
    }

    public static var keyFaceStyle: KeyFaceStyle {
        get {
            guard let raw = defaults.string(forKey: keyFaceStyleKey),
                  let style = KeyFaceStyle(rawValue: raw) else {
                // Default: ritual keys, English text (simple path for fans).
                return .runeArt
            }
            return style
        }
        set { defaults.set(newValue.rawValue, forKey: keyFaceStyleKey) }
    }

    public static var hapticsEnabled: Bool {
        get {
            if defaults.object(forKey: hapticsKey) == nil { return true }
            return defaults.bool(forKey: hapticsKey)
        }
        set { defaults.set(newValue, forKey: hapticsKey) }
    }

    /// Small Latin letter under rune art keys (learning aid).
    public static var showLatinHints: Bool {
        get {
            if defaults.object(forKey: showLatinHintsKey) == nil { return false }
            return defaults.bool(forKey: showLatinHintsKey)
        }
        set { defaults.set(newValue, forKey: showLatinHintsKey) }
    }
}
