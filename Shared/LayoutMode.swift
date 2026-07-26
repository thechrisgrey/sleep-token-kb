import Foundation

/// Keyboard presentation mode. Persisted via App Group UserDefaults.
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

/// Shared preferences between host app and keyboard extension.
public enum KeyboardPreferences {
    public static let appGroupID = "group.com.altivum.SleepTokenKB"
    public static let layoutModeKey = "layoutMode"
    public static let hapticsKey = "hapticsEnabled"
    public static let showLatinHintsKey = "showLatinHints"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static var layoutMode: LayoutMode {
        get {
            guard let raw = defaults.string(forKey: layoutModeKey),
                  let mode = LayoutMode(rawValue: raw) else {
                return .qwerty
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: layoutModeKey)
        }
    }

    public static var hapticsEnabled: Bool {
        get {
            if defaults.object(forKey: hapticsKey) == nil { return true }
            return defaults.bool(forKey: hapticsKey)
        }
        set { defaults.set(newValue, forKey: hapticsKey) }
    }

    /// When true, small Latin letter appears under each symbol (learning mode).
    public static var showLatinHints: Bool {
        get {
            if defaults.object(forKey: showLatinHintsKey) == nil { return false }
            return defaults.bool(forKey: showLatinHintsKey)
        }
        set { defaults.set(newValue, forKey: showLatinHintsKey) }
    }
}
