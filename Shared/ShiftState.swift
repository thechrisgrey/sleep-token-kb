import Foundation

/// The keyboard's three shift states.
///
/// Previously encoded as two overlapping `Bool`s (`isShifted` / `isCapsLock`), which made
/// the illegal fourth combination representable and collapsed caps lock and one-shot shift
/// into one flag before the shift key could tell them apart.
public enum ShiftState: String, CaseIterable, Equatable, Sendable {
    /// Lowercase.
    case off
    /// The next letter is capitalised, then shift falls away.
    case shifted
    /// Every letter is capitalised until shift is tapped again.
    case capsLocked

    /// Whether the next inserted letter is uppercase.
    public var isUppercase: Bool { self != .off }

    /// Tapping the shift key: off -> shifted -> capsLocked -> off.
    public func toggled() -> ShiftState {
        switch self {
        case .off: .shifted
        case .shifted: .capsLocked
        case .capsLocked: .off
        }
    }

    /// Applied after a letter is inserted: one-shot shift falls away, caps lock persists.
    public func afterInsert() -> ShiftState {
        self == .shifted ? .off : self
    }

    /// SF Symbol for the shift key, distinct per state so caps lock is visible.
    public var symbolName: String {
        switch self {
        case .off: "shift"
        case .shifted: "shift.fill"
        case .capsLocked: "capslock.fill"
        }
    }

    /// Spoken by VoiceOver as the shift key's value, so the three states are distinguishable.
    public var accessibilityValue: String {
        switch self {
        case .off: "off"
        case .shifted: "on for one letter"
        case .capsLocked: "caps lock on"
        }
    }
}
