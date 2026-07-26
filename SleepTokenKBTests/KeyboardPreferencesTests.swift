import XCTest
@testable import SleepTokenKB

/// Reads/writes the same App Group suite as `KeyboardPreferences` (it hardcodes
/// its own suite, so there's nothing to inject) — every test restores whatever
/// was there before it ran, so the suite is left exactly as it was found.
final class KeyboardPreferencesTests: XCTestCase {
    private var defaults: UserDefaults {
        UserDefaults(suiteName: KeyboardPreferences.appGroupID) ?? .standard
    }

    private var originalLayoutMode: String?
    private var originalHaptics: Bool?
    private var originalShowHints: Bool?
    private var originalKeyFaceStyle: String?

    override func setUpWithError() throws {
        originalLayoutMode = defaults.string(forKey: KeyboardPreferences.layoutModeKey)
        originalHaptics = defaults.object(forKey: KeyboardPreferences.hapticsKey) as? Bool
        originalShowHints = defaults.object(forKey: KeyboardPreferences.showLatinHintsKey) as? Bool
        originalKeyFaceStyle = defaults.string(forKey: KeyboardPreferences.keyFaceStyleKey)
    }

    override func tearDownWithError() throws {
        restore(KeyboardPreferences.layoutModeKey, originalLayoutMode)
        restore(KeyboardPreferences.hapticsKey, originalHaptics)
        restore(KeyboardPreferences.showLatinHintsKey, originalShowHints)
        restore(KeyboardPreferences.keyFaceStyleKey, originalKeyFaceStyle)
    }

    private func restore(_ key: String, _ value: Any?) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func testLayoutModeDefaultsToQwerty() {
        defaults.removeObject(forKey: KeyboardPreferences.layoutModeKey)
        XCTAssertEqual(KeyboardPreferences.layoutMode, .qwerty)
    }

    func testLayoutModeRoundTrips() {
        KeyboardPreferences.layoutMode = .grid
        XCTAssertEqual(KeyboardPreferences.layoutMode, .grid)
        KeyboardPreferences.layoutMode = .qwerty
        XCTAssertEqual(KeyboardPreferences.layoutMode, .qwerty)
    }

    func testHapticsDefaultsToTrue() {
        defaults.removeObject(forKey: KeyboardPreferences.hapticsKey)
        XCTAssertTrue(KeyboardPreferences.hapticsEnabled)
    }

    func testShowLatinHintsDefaultsToFalse() {
        defaults.removeObject(forKey: KeyboardPreferences.showLatinHintsKey)
        XCTAssertFalse(KeyboardPreferences.showLatinHints)
    }

    func testKeyFaceStyleDefaultsToRuneArt() {
        defaults.removeObject(forKey: KeyboardPreferences.keyFaceStyleKey)
        XCTAssertEqual(KeyboardPreferences.keyFaceStyle, .runeArt)
    }
}
