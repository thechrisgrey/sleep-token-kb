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

    /// Fits the narrow chrome key. `title` is too long there, and the old hand-shortened
    /// literal in the keyboard was misspelled "QWRTY".
    public var shortTitle: String {
        switch self {
        case .qwerty: "QWERTY"
        case .grid: "A–Z"
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

    /// Names the key *style* rather than an alphabet, so the chrome key can never show
    /// the same text as the neighbouring 123/ABC page key.
    public var shortTitle: String {
        switch self {
        case .runeArt: "Rune"
        case .letters: "Aa"
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

    /// Values the host app owns. `static let` rather than a computed property: the old
    /// version built a fresh `UserDefaults` on *every* access, and the keystroke path
    /// reads `hapticsEnabled` before each insert. A `static let` is lazily initialised
    /// and thread-safe, so the suite is constructed once per process.
    private static let shared = UserDefaults(suiteName: appGroupID)

    /// Always writable from either process. A keyboard extension running without Full
    /// Access cannot reach the App Group container, so its own in-keyboard toggles are
    /// persisted here instead of being silently dropped.
    private static let local = UserDefaults.standard

    /// App Group wins when it has a value (the host app is the source of truth);
    /// otherwise fall back to whatever this process stored locally.
    private static func storedString(_ key: String) -> String? {
        shared?.string(forKey: key) ?? local.string(forKey: key)
    }

    private static func storedBool(_ key: String, default fallback: Bool) -> Bool {
        if let shared, shared.object(forKey: key) != nil { return shared.bool(forKey: key) }
        if local.object(forKey: key) != nil { return local.bool(forKey: key) }
        return fallback
    }

    /// Write to both. The App Group write is the one that reaches the other process and
    /// is a no-op when the sandbox denies it; the local write is what survives relaunch
    /// inside the extension.
    private static func store(_ value: Any, _ key: String) {
        local.set(value, forKey: key)
        shared?.set(value, forKey: key)
    }

    public static var layoutMode: LayoutMode {
        get {
            guard let raw = storedString(layoutModeKey),
                  let mode = LayoutMode(rawValue: raw) else { return .qwerty }
            return mode
        }
        set { store(newValue.rawValue, layoutModeKey) }
    }

    public static var keyFaceStyle: KeyFaceStyle {
        get {
            guard let raw = storedString(keyFaceStyleKey),
                  let style = KeyFaceStyle(rawValue: raw) else {
                // Default: ritual keys, English text (simple path for fans).
                return .runeArt
            }
            return style
        }
        set { store(newValue.rawValue, keyFaceStyleKey) }
    }

    public static var hapticsEnabled: Bool {
        get { storedBool(hapticsKey, default: true) }
        set { store(newValue, hapticsKey) }
    }

    /// Small Latin letter under rune art keys (learning aid).
    public static var showLatinHints: Bool {
        get { storedBool(showLatinHintsKey, default: false) }
        set { store(newValue, showLatinHintsKey) }
    }
}
