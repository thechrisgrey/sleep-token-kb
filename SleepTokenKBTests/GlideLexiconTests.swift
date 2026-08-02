// SleepTokenKBTests/GlideLexiconTests.swift
import XCTest
@testable import SleepTokenKB

final class GlideLexiconTests: XCTestCase {

    /// Toy geometry: three keys on a line, 100pt apart.
    private let centers: [SleepTokenLetter: CGPoint] = [
        .a: CGPoint(x: 0, y: 0), .s: CGPoint(x: 100, y: 0), .d: CGPoint(x: 200, y: 0),
    ]

    func testPathCollapsesAdjacentDuplicatesAndStripsApostrophes() {
        let lexicon = GlideLexicon(rows: [("hello", 100), ("don't", 50)])
        let hello = lexicon.candidates(
            startingNear: CGPoint(x: 0, y: 0), endingNear: CGPoint(x: 0, y: 0),
            centers: [.h: .zero, .e: .zero, .l: .zero, .o: .zero,
                      .d: .zero, .n: .zero, .t: .zero],
            radius: 10
        )
        let paths = Dictionary(uniqueKeysWithValues: hello.map { ($0.word, $0.path) })
        XCTAssertEqual(paths["hello"], [.h, .e, .l, .o], "adjacent double letters share one key")
        XCTAssertEqual(paths["don't"], [.d, .o, .n, .t], "the apostrophe is not a key")
    }

    func testCandidatesArePrunedByFirstAndLastKey() {
        let lexicon = GlideLexicon(rows: [("as", 100), ("ad", 90), ("sad", 80), ("dad", 70)])
        let fromA = lexicon.candidates(
            startingNear: CGPoint(x: 5, y: 0), endingNear: CGPoint(x: 105, y: 0),
            centers: centers, radius: 30
        )
        XCTAssertEqual(Set(fromA.map(\.word)), ["as"], "only a→s survives both gates")
    }

    func testFrequencyIsNormalizedAndOrdered() {
        let lexicon = GlideLexicon(rows: [("as", 1_000_000), ("ad", 10)])
        let all = lexicon.candidates(
            startingNear: .zero, endingNear: CGPoint(x: 300, y: 0),
            centers: centers, radius: 1_000
        )
        let byWord = Dictionary(uniqueKeysWithValues: all.map { ($0.word, $0.frequency) })
        XCTAssertEqual(byWord["as"] ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(byWord["ad"] ?? 0, 0.0, accuracy: 0.0001)
    }

    func testMergedSupplementaryWordsBecomeCandidates() {
        let lexicon = GlideLexicon(rows: [("as", 100)])
        lexicon.merge(words: ["Ada"])
        let found = lexicon.candidates(
            startingNear: .zero, endingNear: CGPoint(x: 5, y: 0),
            centers: centers, radius: 250
        )
        XCTAssertTrue(found.contains { $0.word == "Ada" && $0.path == [.a, .d, .a] })
        lexicon.merge(words: ["Ada"])   // idempotent
        XCTAssertEqual(found.filter { $0.word == "Ada" }.count, 1)
    }

    func testBundledLexiconLoadsWithContractions() {
        let lexicon = GlideLexicon.shared
        XCTAssertGreaterThan(lexicon.wordCount, 45_000)
        XCTAssertTrue(lexicon.containsWord("the"))
        XCTAssertTrue(lexicon.containsWord("don't"))
        XCTAssertFalse(lexicon.containsWord("a"), "single-letter words are tap territory")
    }
}
