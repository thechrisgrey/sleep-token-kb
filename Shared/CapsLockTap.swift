import Foundation

/// Double-tap-shift-for-caps-lock, the way stock iOS does it.
///
/// The quick second tap is the road INTO caps lock, and a tap on the locked state is the
/// road out. The three-tap cycle this keyboard once walked is gone: with the double tap
/// owning caps lock, the cycle's middle step only turned a change of mind into ALL CAPS.
///
/// Time is passed in rather than read from a clock so the window is testable, matching
/// how `PeriodShortcut` and `SpaceTracker` already handle their windows.
public struct CapsLockTap {
    /// Forgiving enough for a thumb, tight enough not to swallow two deliberate taps.
    public static let window: TimeInterval = 0.35

    private var lastTap: TimeInterval?

    public init() {}

    /// Records a shift tap and reports whether it completed a double tap.
    ///
    /// A double tap *consumes* the window, so three quick taps read as one double tap
    /// followed by a fresh single — not two overlapping double taps, which would engage
    /// caps lock and immediately re-engage it.
    public mutating func isDoubleTap(at time: TimeInterval) -> Bool {
        if let last = lastTap, time - last <= Self.window {
            lastTap = nil
            return true
        }
        lastTap = time
        return false
    }

    /// A field switch or an external text change abandons the pending tap.
    public mutating func interrupt() {
        lastTap = nil
    }
}
