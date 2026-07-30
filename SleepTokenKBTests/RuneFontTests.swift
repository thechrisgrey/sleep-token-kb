import XCTest
import CoreText
import UIKit
@testable import SleepTokenKB

/// `RuneFont` had no tests at all, and its failure mode is silent: every accessor falls
/// back to a system face rather than throwing, so a font that failed to ship or lost a
/// glyph in `scripts/build_rune_font.py` renders as plain Latin text instead of runes and
/// nothing reports it.
///
/// These run against the real bundle. The test target has a TEST_HOST, so `Bundle.main` is
/// SleepTokenKB.app and the `UIAppFonts` declaration applies exactly as it does at runtime.
final class RuneFontTests: XCTestCase {

    func testTheFontFileShipsInTheAppBundle() {
        XCTAssertNotNil(
            RuneFont.fontURL,
            "SleepTokenRunes.ttf is not in the bundle -- Rune Pad would silently render Latin"
        )
    }

    func testTheFaceIsAvailableInThisProcess() {
        XCTAssertTrue(
            RuneFont.isAvailableInProcess,
            "UIAppFonts should have loaded the face; without it every glyph falls back"
        )
    }

    /// Registration is documented as once per process; calling it repeatedly is what every
    /// view does, and the second call must be both cheap and consistent.
    func testEnsureLoadedIsIdempotent() {
        let first = RuneFont.ensureLoaded()
        let second = RuneFont.ensureLoaded()
        XCTAssertEqual(first, second)
        XCTAssertTrue(second)
    }

    func testRegisterIfNeededAgreesWithEnsureLoaded() {
        XCTAssertEqual(RuneFont.registerIfNeeded(), RuneFont.ensureLoaded())
    }

    /// The fallback chain ends in `.systemFont(ofSize:)`, so a size regression would be
    /// invisible: the text still draws, just at the wrong scale.
    func testUIFontHonoursTheRequestedSize() {
        for size in [9, 17, 24, 64] as [CGFloat] {
            XCTAssertEqual(RuneFont.uiFont(size: size).pointSize, size, accuracy: 0.001)
        }
    }

    func testUIFontResolvesToTheRuneFaceRatherThanTheFallback() {
        let font = RuneFont.uiFont(size: 24)
        XCTAssertEqual(
            font.familyName, RuneFont.familyName,
            "resolved to \(font.familyName) -- the system fallback was used instead of the rune face"
        )
    }

    func testThePostScriptNameBelongsToTheDeclaredFamily() {
        XCTAssertTrue(
            RuneFont.postScriptName.hasPrefix(RuneFont.familyName),
            "PostScript name and family name have drifted apart"
        )
    }

    /// The real payload test: every letter must map to a drawable glyph in the Private Use
    /// range. This is what catches a regenerated font that dropped or shifted a glyph.
    func testEveryLetterHasAGlyphInThePrivateUseRange() throws {
        try XCTSkipUnless(RuneFont.isAvailableInProcess, "rune face unavailable in this process")
        let font = RuneFont.uiFont(size: 24) as CTFont

        for letter in SleepTokenLetter.allCases {
            var characters = Array(letter.exactRuneString.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            let resolved = CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)

            XCTAssertTrue(resolved, "no glyph mapping for \(letter.upperLatin)")
            XCTAssertNotEqual(glyphs[0], 0, "\(letter.upperLatin) resolves to .notdef")
        }
    }

    /// Distinct letters must not collapse onto one glyph, which a mis-generated font can do
    /// while still passing the "has a glyph" check above.
    func testEveryLetterMapsToADistinctGlyph() throws {
        try XCTSkipUnless(RuneFont.isAvailableInProcess, "rune face unavailable in this process")
        let font = RuneFont.uiFont(size: 24) as CTFont

        let resolved: [CGGlyph] = SleepTokenLetter.allCases.map { letter in
            var characters = Array(letter.exactRuneString.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            _ = CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
            return glyphs[0]
        }

        XCTAssertEqual(
            Set(resolved).count, SleepTokenLetter.allCases.count,
            "two or more letters share a glyph"
        )
    }

    func testFontAccessorNeverReturnsAZeroSize() {
        XCTAssertGreaterThan(RuneFont.uiFont(size: 12).pointSize, 0)
    }
}
