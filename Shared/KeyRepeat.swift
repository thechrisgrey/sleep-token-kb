import Foundation

/// Timing for a held key that repeats, which for this keyboard means delete.
///
/// Pure arithmetic rather than a timer so the curve can be asserted directly. The shape is
/// the conventional one: a long pause that distinguishes a tap from a hold, a steady rate
/// while the user reads what is disappearing, then a faster rate once it is clear they
/// mean to clear the field.
public enum KeyRepeat {

    /// Pause before the first repeat. Without it an ordinary tap deletes two characters.
    public static let initialDelay: TimeInterval = 0.4

    /// The steady rate, roughly eight characters a second.
    public static let baseInterval: TimeInterval = 0.12

    /// The accelerated rate, and the floor: fast enough to clear a paragraph, slow enough
    /// that the user can still release before overshooting.
    public static let fastInterval: TimeInterval = 0.05

    /// Repeats at the base rate before acceleration kicks in — about a second and a half
    /// of holding, or one short word.
    public static let accelerateAfter: Int = 12

    /// The wait before the `count`-th repeat, counting from 1.
    public static func interval(forRepeat count: Int) -> TimeInterval {
        count > accelerateAfter ? fastInterval : baseInterval
    }
}
