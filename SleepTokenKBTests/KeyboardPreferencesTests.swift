import XCTest
@testable import SleepTokenKB

/// Reads/writes the same App Group suite as `KeyboardPreferences` (it hardcodes
/// its own suite, so there's nothing to inject) — every test restores whatever
/// was there before it ran, so the suite is left exactly as it was found.
///
/// `KeyboardPreferences` writes both the App Group suite and `UserDefaults.standard`
/// (the extension's no-Full-Access fallback), so both are snapshotted and restored.
final class KeyboardPreferencesTests: XCTestCase {
    private var suites: [UserDefaults] {
        var all: [UserDefaults] = [.standard]
        if let group = UserDefaults(suiteName: KeyboardPreferences.appGroupID) {
            all.append(group)
        }
        return all
    }

    private let trackedKeys = [
        KeyboardPreferences.layoutModeKey,
        KeyboardPreferences.keyFaceStyleKey,
        KeyboardPreferences.hapticsKey,
        KeyboardPreferences.showLatinHintsKey,
        KeyboardPreferences.glideTypingKey
    ]

    /// One snapshot per suite, keyed by suite index then preference key.
    private var snapshots: [[String: Any]] = []

    override func setUpWithError() throws {
        snapshots = suites.map { suite in
            trackedKeys.reduce(into: [:]) { snapshot, key in
                snapshot[key] = suite.object(forKey: key)
            }
        }
    }

    override func tearDownWithError() throws {
        for (suite, snapshot) in zip(suites, snapshots) {
            for key in trackedKeys {
                if let value = snapshot[key] {
                    suite.set(value, forKey: key)
                } else {
                    suite.removeObject(forKey: key)
                }
            }
        }
    }

    private func removeEverywhere(_ key: String) {
        for suite in suites { suite.removeObject(forKey: key) }
    }

    private func setEverywhere(_ value: Any, _ key: String) {
        for suite in suites { suite.set(value, forKey: key) }
    }

    func testLayoutModeDefaultsToQwerty() {
        removeEverywhere(KeyboardPreferences.layoutModeKey)
        XCTAssertEqual(KeyboardPreferences.layoutMode, .qwerty)
    }

    func testLayoutModeRoundTrips() {
        KeyboardPreferences.layoutMode = .grid
        XCTAssertEqual(KeyboardPreferences.layoutMode, .grid)
        KeyboardPreferences.layoutMode = .qwerty
        XCTAssertEqual(KeyboardPreferences.layoutMode, .qwerty)
    }

    func testHapticsDefaultsToTrue() {
        removeEverywhere(KeyboardPreferences.hapticsKey)
        XCTAssertTrue(KeyboardPreferences.hapticsEnabled)
    }

    func testKeyFaceStyleDefaultsToRuneArt() {
        removeEverywhere(KeyboardPreferences.keyFaceStyleKey)
        removeEverywhere(KeyboardPreferences.showLatinHintsKey)
        XCTAssertEqual(KeyboardPreferences.keyFaceStyle, .runeArt)
    }

    func testKeyFaceStyleRoundTripsAllThreeFaces() {
        for style in KeyFaceStyle.allCases {
            KeyboardPreferences.keyFaceStyle = style
            XCTAssertEqual(KeyboardPreferences.keyFaceStyle, style)
        }
    }

    /// Hints used to be a separate bool beside `runeArt`. A device upgrading with that
    /// pair stored must come back as the merged `runeHints` face, not lose its hints.
    func testLegacyRuneArtWithHintsOnMigratesToRuneHints() {
        setEverywhere(KeyFaceStyle.runeArt.rawValue, KeyboardPreferences.keyFaceStyleKey)
        setEverywhere(true, KeyboardPreferences.showLatinHintsKey)
        XCTAssertEqual(KeyboardPreferences.keyFaceStyle, .runeHints)
    }

    func testLegacyRuneArtWithHintsOffStaysRuneArt() {
        setEverywhere(KeyFaceStyle.runeArt.rawValue, KeyboardPreferences.keyFaceStyleKey)
        setEverywhere(false, KeyboardPreferences.showLatinHintsKey)
        XCTAssertEqual(KeyboardPreferences.keyFaceStyle, .runeArt)
    }

    /// Choosing plain runes after runeHints must stick: the setter clears the legacy
    /// bool, otherwise the migration read would re-promote `runeArt` to hints forever.
    func testChoosingRuneArtAfterRuneHintsDoesNotBounceBack() {
        KeyboardPreferences.keyFaceStyle = .runeHints
        KeyboardPreferences.keyFaceStyle = .runeArt
        XCTAssertEqual(KeyboardPreferences.keyFaceStyle, .runeArt)
    }

    func testGlideTypingDefaultsOnAndRoundTrips() {
        XCTAssertTrue(KeyboardPreferences.glideTypingEnabled, "glide ships on")
        KeyboardPreferences.glideTypingEnabled = false
        XCTAssertFalse(KeyboardPreferences.glideTypingEnabled)
        KeyboardPreferences.glideTypingEnabled = true
        XCTAssertTrue(KeyboardPreferences.glideTypingEnabled)
    }
}
