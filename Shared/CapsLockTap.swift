import Foundation

/// Double-tap-shift-for-caps-lock, the way stock iOS does it.
///
/// Our shift key only had the three-tap cycle (off → shifted → capsLocked → off). That
/// reaches caps lock, but it is not the gesture an iPhone user's thumb already knows.
/// Both now work: a quick second tap jumps straight to caps lock, and a slow third tap
/// still walks the cycle.
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
