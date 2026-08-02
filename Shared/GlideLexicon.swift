import CoreGraphics
import Foundation

/// One glide-typable word: its display form, the key path that draws it, and a
/// log-normalized frequency the decoder blends into its score.
public struct GlideWord: Equatable {
    public let word: String
    public let path: [SleepTokenLetter]
    public let frequency: Double
}

/// The glide dictionary. Bundled words come from `glide_lexicon.txt` (built by
/// scripts/build_glide_lexicon.py); the user's supplementary lexicon (contact
/// names, text replacements) merges in at a fixed mid-high frequency. Entries
/// are bucketed by first path letter so pruning touches a fraction of the list.
public final class GlideLexicon {

    private struct Entry {
        let word: String
        let path: [SleepTokenLetter]
        let frequency: Double
    }

    private var buckets: [SleepTokenLetter: [Entry]] = [:]
    private var known: Set<String> = []
    public private(set) var wordCount = 0

    /// Loaded lazily on first use; `prepareForAppearance` warms it off-main so the
    /// first glide never pays the parse.
    public static let shared: GlideLexicon = {
        guard let url = Bundle(for: GlideLexicon.self)
            .url(forResource: "glide_lexicon", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return GlideLexicon(rows: [])
        }
        let rows: [(String, Double)] = text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t")
            guard parts.count == 2, let count = Double(parts[1]) else { return nil }
            return (String(parts[0]), count)
        }
        return GlideLexicon(rows: rows)
    }()

    public init(rows: [(word: String, count: Double)]) {
        guard !rows.isEmpty else { return }
        let logs = rows.map { log(max($0.count, 1)) }
        let lo = logs.min()!, hi = logs.max()!
        let span = max(hi - lo, .ulpOfOne)
        for (row, logCount) in zip(rows, logs) {
            add(word: row.word, frequency: (logCount - lo) / span)
        }
    }

    /// Contact names and text replacements from `requestSupplementaryLexicon`.
    /// Fixed 0.7 frequency: a name should outrank mid-list vocabulary. Idempotent.
    public func merge(words: [String]) {
        for word in words { add(word: word, frequency: 0.7) }
    }

    private func add(word: String, frequency: Double) {
        let path = Self.path(of: word)
        guard path.count >= 2, !known.contains(word.lowercased()) else { return }
        known.insert(word.lowercased())
        wordCount += 1
        buckets[path[0], default: []].append(Entry(word: word, path: path, frequency: frequency))
    }

    /// Lowercased letters only, adjacent duplicates collapsed: the finger visits
    /// "l" once in "hello", and the apostrophe in "don't" is not a key.
    static func path(of word: String) -> [SleepTokenLetter] {
        var result: [SleepTokenLetter] = []
        for character in word.lowercased() {
            guard let letter = SleepTokenLetter(rawValue: String(character)) else { continue }
            if result.last != letter { result.append(letter) }
        }
        return result
    }

    public func containsWord(_ word: String) -> Bool { known.contains(word.lowercased()) }

    /// Every word whose first path key is within `radius` of the trace start AND
    /// whose last path key is within `radius` of the trace end.
    public func candidates(
        startingNear start: CGPoint,
        endingNear end: CGPoint,
        centers: [SleepTokenLetter: CGPoint],
        radius: CGFloat
    ) -> [GlideWord] {
        let startLetters = centers.filter { hypot($0.value.x - start.x, $0.value.y - start.y) <= radius }
        var results: [GlideWord] = []
        for letter in startLetters.keys {
            for entry in buckets[letter] ?? [] {
                guard let lastCenter = centers[entry.path.last!] else { continue }
                guard hypot(lastCenter.x - end.x, lastCenter.y - end.y) <= radius else { continue }
                results.append(GlideWord(word: entry.word, path: entry.path, frequency: entry.frequency))
            }
        }
        return results
    }
}
