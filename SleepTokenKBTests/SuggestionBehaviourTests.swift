import XCTest
@testable import SleepTokenKB

/// What auto-replacement actually does to real vocabulary, measured against the live
/// `UITextChecker` rather than assumed. Silent replacement of a word someone meant is the
/// worst failure this feature has, so the behaviour is recorded here instead of guessed.
final class SuggestionBehaviourTests: XCTestCase {

    /// Prints the verdict for a realistic corpus. Not an assertion — a record, so a
    /// change in the system dictionary shows up as a visible diff in test output rather
    /// than as a surprise on someone's phone.
    func testReportAutoReplacementBehaviour() {
        let engine = SuggestionEngine()
        let corpus = [
            // ordinary typos that SHOULD be fixed
            "teh", "recieve", "seperate", "definately", "occured", "wich",
            // ordinary words that must be left alone
            "keyboard", "ritual", "worship", "listen", "tonight", "quiet",
            // the band's vocabulary, typed as a fan would type it
            "Sleep", "Token", "Vessel", "Euclid", "Arcadia", "Damocles",
            "Sundowning", "Chokehold", "Aqua", "Granite", "Alkaline",
            // things that are never typos
            "abc123", "ok", "hm", "lol", "btw",
        ]
        var replaced: [(String, String)] = []
        var untouched: [String] = []
        for word in corpus {
            if let replacement = engine.autoReplacement(for: word) {
                replaced.append((word, replacement))
            } else {
                untouched.append(word)
            }
        }
        print("=== AUTO-REPLACED (\(replaced.count)) ===")
        for (from, to) in replaced { print("   \(from) -> \(to)") }
        print("=== LEFT ALONE (\(untouched.count)) ===")
        print("   " + untouched.joined(separator: ", "))
    }

    /// Common English must survive untouched. If any of these start being "corrected",
    /// the engine is too aggressive to ship.
    func testOrdinaryWordsAreNeverTouched() {
        let engine = SuggestionEngine()
        for word in ["keyboard", "ritual", "worship", "listen", "tonight", "quiet",
                     "message", "sending", "before", "because"] {
            XCTAssertNil(
                engine.autoReplacement(for: word),
                "\(word) would be silently replaced"
            )
        }
    }

    /// Real typos must actually get fixed, or the feature does nothing.
    func testCommonTyposAreFixed() {
        let engine = SuggestionEngine()
        for typo in ["teh", "recieve", "seperate"] {
            XCTAssertNotNil(
                engine.autoReplacement(for: typo),
                "\(typo) should have been corrected"
            )
        }
    }

    /// Whatever the dictionary thinks of the band's vocabulary, one tap on the literal
    /// has to settle it permanently. This is the escape hatch the whole design rests on.
    func testKeepingAWordSurvivesRepeatedUse() {
        let engine = SuggestionEngine()
        for word in ["Sundowning", "Chokehold", "Euclid"] {
            engine.keepAsTyped(word)
            XCTAssertNil(engine.autoReplacement(for: word), "\(word) still corrected")
            XCTAssertNil(engine.autoReplacement(for: word.lowercased()))
        }
    }
}
