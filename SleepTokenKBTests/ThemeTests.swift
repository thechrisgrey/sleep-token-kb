import XCTest
@testable import SleepTokenKB

/// `ThemeStore` is a singleton over `UserDefaults.standard`; each test restores both
/// the stored value and the live store's mode, leaving them exactly as found.
final class ThemeTests: XCTestCase {
    private var originalStored: String?
    private var originalMode: ThemeMode = .ritual

    override func setUpWithError() throws {
        originalStored = UserDefaults.standard.string(forKey: ThemeStore.storageKey)
        originalMode = ThemeStore.shared.mode
    }

    override func tearDownWithError() throws {
        ThemeStore.shared.mode = originalMode
        if let originalStored {
            UserDefaults.standard.set(originalStored, forKey: ThemeStore.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ThemeStore.storageKey)
        }
    }

    /// The raw values are the on-disk persistence format — renaming a case silently
    /// resets every user who had picked it.
    func testModeRawValuesAreStable() {
        XCTAssertEqual(ThemeMode.ritual.rawValue, "ritual")
        XCTAssertEqual(ThemeMode.evenInArcadia.rawValue, "evenInArcadia")
    }

    func testModeChangePersistsToDefaults() {
        ThemeStore.shared.mode = .evenInArcadia
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: ThemeStore.storageKey),
            ThemeMode.evenInArcadia.rawValue
        )
        ThemeStore.shared.mode = .ritual
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: ThemeStore.storageKey),
            ThemeMode.ritual.rawValue
        )
    }

    /// An unknown stored value (from a future build) must fall back to ritual
    /// rather than crash — mirrors how `KeyboardPreferences` treats bad raws.
    func testUnknownStoredValueFallsBackToRitual() {
        XCTAssertNil(ThemeMode(rawValue: "next-album-theme"))
    }

    /// Exercises the store's REAL init fallback (not just the enum): a seeded
    /// suite with a garbage value must construct a ritual-mode store.
    func testStoreInitFallsBackToRitualOnUnknownStoredValue() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "ThemeTests-scratch"))
        defer { suite.removeObject(forKey: ThemeStore.storageKey) }

        suite.set("next-album-theme", forKey: ThemeStore.storageKey)
        XCTAssertEqual(ThemeStore(defaults: suite).mode, .ritual)

        suite.set(ThemeMode.evenInArcadia.rawValue, forKey: ThemeStore.storageKey)
        XCTAssertEqual(ThemeStore(defaults: suite).mode, .evenInArcadia)
    }

    /// The load-bearing behaviour of the whole system: flipping the mode must
    /// actually resolve the palette differently.
    func testPaletteResolvesDifferentlyPerMode() {
        ThemeStore.shared.mode = .ritual
        let ritualGold = Theme.gold
        let ritualSurface = Theme.surface
        let ritualCanvas = Theme.canvasSurface

        ThemeStore.shared.mode = .evenInArcadia
        XCTAssertNotEqual(Theme.gold, ritualGold)
        XCTAssertNotEqual(Theme.surface, ritualSurface)
        XCTAssertNotEqual(Theme.canvasSurface, ritualCanvas)
        XCTAssertEqual(Theme.gold, Theme.arcadiaRose, "Arcadia's accent is the fixed rose")
    }

    /// The petal field's layout hash must be deterministic: the same index always
    /// lands in the same place, or the sky reshuffles on every render.
    func testPetalHashIsDeterministicAndBounded() {
        for index in 0..<50 {
            let a = PetalField.hash01(index, 3)
            let b = PetalField.hash01(index, 3)
            XCTAssertEqual(a, b)
            XCTAssertGreaterThanOrEqual(a, 0)
            XCTAssertLessThan(a, 1)
        }
    }
}
