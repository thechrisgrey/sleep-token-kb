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
}
