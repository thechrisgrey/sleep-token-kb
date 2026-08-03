// Shared/GlideSession.swift
import CoreGraphics

/// Collects one glide's touch samples. A value type held in `@State` so every
/// appended point invalidates the trail overlay; the movement threshold that
/// distinguishes tap from glide lives at the gesture layer
/// (`DragGesture(minimumDistance:)`), not here.
public struct GlideSession: Equatable {
    public private(set) var points: [CGPoint] = []

    public var isActive: Bool { !points.isEmpty }

    public init() {}

    /// Appends a sample. One drag keeps one start location for its whole life,
    /// so a differing `start` can only mean a new gesture — the previous
    /// session was abandoned by a cancelled touch and is replaced, not
    /// continued.
    public mutating func extend(start: CGPoint, to current: CGPoint) {
        if points.isEmpty || points.first != start {
            points = [start]
        }
        points.append(current)
    }

    /// The completed trace, ending at the lift point. Resets for the next glide.
    public mutating func finish(at final: CGPoint) -> [CGPoint] {
        guard isActive else { return [] }
        points.append(final)
        defer { points = [] }
        return points
    }

    public mutating func cancel() { points = [] }
}
