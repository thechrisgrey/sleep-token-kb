// Shared/GlideDecoder.swift
import CoreGraphics
import Foundation

/// Path-template matching: score the finger's trace against each candidate word's
/// ideal polyline through the key centers (SHARK² lineage). Deterministic and
/// synchronous — decode runs on lift, on the main actor, inside a strict budget;
/// pruning (GlideLexicon) keeps the scored set in the hundreds.
public enum GlideDecoder {

    public struct Result: Equatable {
        public let word: String
        public let score: Double   // lower is better
    }

    public static let sampleCount = 64
    public static let pruneRadiusFactor: CGFloat = 1.5
    public static let widenedPruneRadiusFactor: CGFloat = 2.5
    public static let frequencyWeight = 0.45
    /// Start/end anchoring: where a glide begins and ends is the user's most
    /// deliberate signal, so endpoint misses cost more than mid-path wobble.
    public static let endpointWeight = 0.35

    public static func decode(
        trace: [CGPoint],
        centers: [SleepTokenLetter: CGPoint],
        keyUnit: CGFloat,
        lexicon: GlideLexicon,
        limit: Int = 4
    ) -> [Result] {
        guard let start = trace.first, let end = trace.last, trace.count >= 2 else { return [] }

        var pool = lexicon.candidates(startingNear: start, endingNear: end,
                                      centers: centers, radius: pruneRadiusFactor * keyUnit)
        if pool.isEmpty {
            // One widening only: the trace may have started sloppily off-key.
            pool = lexicon.candidates(startingNear: start, endingNear: end,
                                      centers: centers, radius: widenedPruneRadiusFactor * keyUnit)
        }
        guard !pool.isEmpty else { return [] }

        let sampled = resample(trace, to: sampleCount)
        let traceLength = length(of: trace)

        var results: [Result] = []
        results.reserveCapacity(pool.count)
        for candidate in pool {
            let polyline = candidate.path.compactMap { centers[$0] }
            guard polyline.count == candidate.path.count else { continue }
            let templateLength = length(of: polyline)
            // A word whose drawn shape is wildly longer or shorter than the trace
            // cannot be what the finger meant, whatever the endpoints say.
            guard templateLength >= 0.3 * traceLength,
                  templateLength <= 3 * traceLength + 2 * keyUnit else { continue }
            let template = resample(polyline, to: sampleCount)
            var total: CGFloat = 0
            for index in 0..<sampleCount {
                total += hypot(sampled[index].x - template[index].x,
                               sampled[index].y - template[index].y)
            }
            let shapeCost = Double(total / CGFloat(sampleCount) / keyUnit)
            let endpointCost = Double(
                (hypot(sampled[0].x - template[0].x,
                       sampled[0].y - template[0].y)
                 + hypot(sampled[sampleCount - 1].x - template[sampleCount - 1].x,
                         sampled[sampleCount - 1].y - template[sampleCount - 1].y))
                / (2 * keyUnit)
            )
            results.append(Result(word: candidate.word,
                                  score: shapeCost + endpointWeight * endpointCost
                                      - frequencyWeight * candidate.frequency))
        }
        return Array(results.sorted { $0.score < $1.score }.prefix(limit))
    }

    /// Last-resort literal: the nearest key under each sampled point, adjacent
    /// duplicates collapsed. The user gets what they drew, never silence.
    public static func nearestLetterSequence(
        trace: [CGPoint],
        centers: [SleepTokenLetter: CGPoint]
    ) -> String {
        guard !centers.isEmpty else { return "" }
        var letters: [SleepTokenLetter] = []
        for point in resample(trace, to: 16) {
            let nearest = centers.min {
                hypot($0.value.x - point.x, $0.value.y - point.y)
                    < hypot($1.value.x - point.x, $1.value.y - point.y)
            }!.key
            if letters.last != nearest { letters.append(nearest) }
        }
        return letters.map(\.latin).joined()
    }

    // MARK: - Geometry

    static func length(of points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        return (1..<points.count).reduce(CGFloat(0)) { (total: CGFloat, index: Int) -> CGFloat in
            total + hypot(points[index].x - points[index - 1].x,
                          points[index].y - points[index - 1].y)
        }
    }

    /// `count` points spaced equally along the polyline's arc length. A single
    /// point (or zero length) repeats itself, so degenerate inputs stay total.
    static func resample(_ points: [CGPoint], to count: Int) -> [CGPoint] {
        guard let first = points.first else { return [] }
        let total = length(of: points)
        guard total > 0, points.count > 1 else {
            return Array(repeating: first, count: count)
        }
        let step = total / CGFloat(count - 1)
        var result = [first]
        var accumulated: CGFloat = 0
        var index = 1
        var previous = first
        while result.count < count - 1, index < points.count {
            let segment = hypot(points[index].x - previous.x, points[index].y - previous.y)
            if accumulated + segment >= step {
                let t = (step - accumulated) / segment
                let next = CGPoint(x: previous.x + t * (points[index].x - previous.x),
                                   y: previous.y + t * (points[index].y - previous.y))
                result.append(next)
                previous = next
                accumulated = 0
            } else {
                accumulated += segment
                previous = points[index]
                index += 1
            }
        }
        while result.count < count { result.append(points.last!) }
        return result
    }
}
