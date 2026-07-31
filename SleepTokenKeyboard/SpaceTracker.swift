import Foundation

/// Tracks whether the previous keystroke was a space, and how long ago, for the
/// double-space-for-period shortcut.
///
/// `ContinuousClock` rather than `Date`: the window is a gesture-timing question, and
/// wall-clock arithmetic goes negative if the system clock shifts backward mid-session.
/// A monotonic instant cannot.
final class SpaceTracker {
    private var lastSpace: ContinuousClock.Instant?

    /// Seconds since the previous space, or infinity when the previous keystroke was
    /// not a space. Infinity (rather than an optional) lets the caller hand the value
    /// straight to `PeriodShortcut.shouldSubstitute`, whose window check rejects it.
    var sinceLastSpace: TimeInterval {
        guard let lastSpace else { return .infinity }
        let elapsed = ContinuousClock.now - lastSpace
        return TimeInterval(elapsed.components.seconds)
            + TimeInterval(elapsed.components.attoseconds) / 1e18
    }

    func recordSpace() {
        lastSpace = .now
    }

    /// Any keystroke that is not a space breaks consecutiveness; so does a field change
    /// and a completed substitution (a third space must not produce a second period).
    func interrupt() {
        lastSpace = nil
    }
}
