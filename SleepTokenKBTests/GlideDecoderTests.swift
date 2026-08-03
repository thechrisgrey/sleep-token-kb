// SleepTokenKBTests/GlideDecoderTests.swift
import XCTest
@testable import SleepTokenKB

/// The accuracy floor for the engine, run on real QWERTY geometry at iPhone width.
/// Ideal traces are the word's own template polyline — if the engine cannot decode
/// its own templates, nothing else matters. Jitter uses a seeded generator: a
/// flaky accuracy suite would teach everyone to ignore it.
final class GlideDecoderTests: XCTestCase {

    private let width: CGFloat = 393
    private var centers: [SleepTokenLetter: CGPoint]!
    private var unit: CGFloat!

    override func setUp() {
        super.setUp()
        centers = KeyCenters.qwerty(availableWidth: width, keyHeight: 40)
        unit = KeyboardMetrics.keyUnit(availableWidth: width)
    }

    private func idealTrace(for word: String) -> [CGPoint] {
        GlideLexicon.path(of: word).map { centers[$0]! }
    }

    private func decode(_ trace: [CGPoint], lexicon: GlideLexicon) -> [String] {
        GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                            lexicon: lexicon, limit: 4).map(\.word)
    }

    func testIdealTracesForCommonWordsDecodeTopOne() {
        let lexicon = GlideLexicon.shared
        for word in ["the", "and", "you", "hello", "keyboard", "ritual", "sleep"] {
            XCTAssertEqual(decode(idealTrace(for: word), lexicon: lexicon).first, word,
                           "ideal trace for '\(word)' must decode first")
        }
    }

    /// Words sharing a collapsed path ("to"/"too") legitimately tie on shape, so
    /// the broad sweep asserts top-3, not top-1.
    func testIdealTracesForTop200WordsDecodeTopThree() {
        let lexicon = GlideLexicon.shared
        for word in lexicon.mostFrequentWords(200) where GlideLexicon.path(of: word).count >= 2 {
            let top = decode(idealTrace(for: word), lexicon: lexicon)
            XCTAssertTrue(top.prefix(3).contains(word),
                          "'\(word)' missing from top-3: \(top)")
        }
    }

    func testJitteredTracesDecodeTopThree() {
        let lexicon = GlideLexicon.shared
        var rng = SplitMix64(seed: 0x5EED)
        var hits = 0
        let words = lexicon.mostFrequentWords(100).filter { GlideLexicon.path(of: $0).count >= 3 }
        for word in words {
            let jittered = idealTrace(for: word).map { (point: CGPoint) -> CGPoint in
                let dx = CGFloat(rng.nextUniform() - 0.5) * unit * 0.5
                let dy = CGFloat(rng.nextUniform() - 0.5) * unit * 0.5
                return CGPoint(x: point.x + dx, y: point.y + dy)
            }
            if decode(jittered, lexicon: lexicon).prefix(3).contains(word) { hits += 1 }
        }
        XCTAssertGreaterThanOrEqual(Double(hits) / Double(words.count), 0.9,
                                    "jittered accuracy fell below 90%")
    }

    /// pit/pot/put share one ideal trace — a straight line along the top row,
    /// because i, o, and u all lie ON the p→t segment. No score over the path
    /// alone can split them; the commit model carries that ambiguity in the
    /// bar, so all three must be offered. Pairs whose mid-path shapes genuinely
    /// differ (form/from swap their zigzag) must still resolve top-1.
    func testAdversarialPairsResolveByPathOrSurfaceInAlternates() {
        let lexicon = GlideLexicon.shared
        let sharedLine = decode(idealTrace(for: "pit"), lexicon: lexicon)
        for word in ["pit", "pot", "put"] {
            XCTAssertTrue(sharedLine.contains(word),
                          "'\(word)' missing from the shared p-t line's candidates: \(sharedLine)")
        }
        XCTAssertEqual(decode(idealTrace(for: "form"), lexicon: lexicon).first, "form")
        XCTAssertEqual(decode(idealTrace(for: "from"), lexicon: lexicon).first, "from")
        XCTAssertTrue(decode(idealTrace(for: "jello"), lexicon: lexicon).prefix(3).contains("jello"))
    }

    func testEmptyCandidatesFallBackToNearestLetters() {
        let empty = GlideLexicon(rows: [])
        let straight = idealTrace(for: "qp")
        XCTAssertTrue(GlideDecoder.decode(trace: straight, centers: centers, keyUnit: unit,
                                          lexicon: empty, limit: 4).isEmpty)
        XCTAssertEqual(GlideDecoder.nearestLetterSequence(trace: straight, centers: centers),
                       "qp", "a straight drag has no corners — only its endpoints speak")
        let elbow = idealTrace(for: "qpm")   // along the top row, then down to m
        XCTAssertEqual(GlideDecoder.nearestLetterSequence(trace: elbow, centers: centers),
                       "qpm", "the corner at p is a deliberate point and must survive")
    }

    /// Regression tripwire, not a benchmark: debug builds run this unoptimized,
    /// so the ceiling is deliberately loose — it catches an accidental
    /// order-of-magnitude regression, not a lost millisecond. The real budget
    /// (50ms, release, on device) is verified by hand on device.
    func testDecodeStaysInsideTheLatencyBudget() {
        let lexicon = GlideLexicon.shared
        let trace = idealTrace(for: "keyboard")
        _ = GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                                lexicon: lexicon, limit: 4)   // warm the lexicon
        let start = ContinuousClock.now
        for _ in 0..<5 {
            _ = GlideDecoder.decode(trace: trace, centers: centers, keyUnit: unit,
                                    lexicon: lexicon, limit: 4)
        }
        let elapsed = ContinuousClock.now - start
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        XCTAssertLessThan(seconds / 5, 0.15, "decode regressed an order of magnitude")
    }
}

/// Deterministic RNG so jitter is identical on every run.
struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func nextUniform() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
