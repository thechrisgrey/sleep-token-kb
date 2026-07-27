import XCTest
@testable import SleepTokenKB

final class AlphabetTests: XCTestCase {
    func testRuneIndexMatchesAlphabetPosition() {
        XCTAssertEqual(SleepTokenLetter.a.runeIndex, 0)
        XCTAssertEqual(SleepTokenLetter.m.runeIndex, 12)
        XCTAssertEqual(SleepTokenLetter.z.runeIndex, 25)
    }

    func testExactRuneCharacterRoundTrips() {
        for letter in SleepTokenLetter.allCases {
            let rune = letter.exactRuneCharacter
            XCTAssertEqual(
                SleepTokenLetter.fromRuneCharacter(rune),
                letter,
                "Round-trip failed for \(letter.rawValue)"
            )
        }
    }

    func testFromRuneCharacterRejectsOutOfRange() {
        XCTAssertNil(SleepTokenLetter.fromRuneCharacter("a"))
        XCTAssertNil(SleepTokenLetter.fromRuneCharacter(Character(UnicodeScalar(SleepTokenLetter.puaBase + 26)!)))
    }

    func testAssetNameFormat() {
        XCTAssertEqual(SleepTokenLetter.a.assetName, "symbol_a")
        XCTAssertEqual(SleepTokenLetter.q.assetName, "symbol_q")
        XCTAssertEqual(SleepTokenLetter.z.assetName, "symbol_z")
    }

    func testEnglishInsertRespectsShiftState() {
        XCTAssertEqual(SleepTokenLetter.a.englishInsert(shifted: false), "a")
        XCTAssertEqual(SleepTokenLetter.a.englishInsert(shifted: true), "A")
    }

    func testLatinTranslationMapsRunesBackToLetters() {
        let runes = [SleepTokenLetter.s, .l, .e, .e, .p]
            .map(\.exactRuneString)
            .joined()
        XCTAssertEqual(SleepTokenLetter.latinTranslation(of: runes), "sleep")
    }

    /// Spaces and any non-rune character (punctuation typed via paste, say) pass
    /// through untouched — the translation must never drop or reorder anything.
    func testLatinTranslationPassesNonRuneCharactersThrough() {
        let mixed = SleepTokenLetter.a.exactRuneString + " b! " + SleepTokenLetter.c.exactRuneString
        XCTAssertEqual(SleepTokenLetter.latinTranslation(of: mixed), "a b! c")
    }

    func testLatinTranslationOfEmptyStringIsEmpty() {
        XCTAssertEqual(SleepTokenLetter.latinTranslation(of: ""), "")
    }

    func testLatinTranslationRoundTripsTheWholeAlphabet() {
        let runes = SleepTokenLetter.allCases.map(\.exactRuneString).joined()
        XCTAssertEqual(
            SleepTokenLetter.latinTranslation(of: runes),
            "abcdefghijklmnopqrstuvwxyz"
        )
    }
}
