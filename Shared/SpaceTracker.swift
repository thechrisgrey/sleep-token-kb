import Foundation

/// Tracks whether the previous keystroke was a space, and how long ago, for the
/// double-space-for-period shortcut.
///
/// `ContinuousClock` rather than `Date`: the window is a gesture-timing question, and
/// wall-clock arithmetic goes negative if the system clock shifts backward mid-session.
/// A monotonic instant cannot.
final class SpaceTracker {
    private var lastSpace: ContinuousClock.Instant?

    /// Set when this keyboard performs an edit whose settle will arrive back as a host
    /// text change. That echo is consumed silently; any host change WITHOUT a pending
    /// echo — a cursor jump, a host-side clear, focusing a same-trait field — is an
    /// interleaving event and closes the window. If two local edits coalesce into one
    /// echo the flag can linger and swallow one external change; that failure direction
    /// merely widens the window briefly, which is the pre-fix status quo.
    private var pendingLocalEcho = false

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

    /// This keyboard performed an edit; expect its settle to echo back once.
    func noteLocalChange() {
        pendingLocalEcho = true
    }

    /// The host document changed. The echo of this keyboard's own keystroke passes
    /// through; anything else breaks consecutiveness.
    func hostTextDidChange() {
        if pendingLocalEcho {
            pendingLocalEcho = false
        } else {
            lastSpace = nil
        }
    }

    /// Any keystroke that is not a space breaks consecutiveness; so does a field change
    /// and a completed substitution (a third space must not produce a second period).
    func interrupt() {
        lastSpace = nil
    }
}
