import Foundation

/// Whether the space bar's return to letters is armed for the current visit to the
/// symbol planes. `PageAfterSpace` carries the rule and receives only the Bool; this is
/// what sets and clears it, which used to be a `@State` flag touched from four places in
/// the view with nothing pinning the two sequences stock actually measures by:
/// `123 5 #+= space` returns to letters, `123 5 ABC 123 space` stays.
public struct SymbolVisit: Equatable {
    /// True once a character has been typed on this visit. Stock arms the return on the
    /// first keystroke of a visit, not on arrival — `123 space` stays on 123 so a
    /// "meet me at " keeps the digits one tap away.
    public private(set) var isArmed = false

    public init() {}

    /// A character landed on a symbol plane.
    public mutating func didType() {
        isArmed = true
    }

    /// Every deliberate page change — ABC, 123, emoji, the space bar's own return —
    /// starts a fresh, disarmed visit.
    public mutating func didChangePage() {
        isArmed = false
    }

    /// The 123 <-> #+= toggle is the deliberate exception: stock counts the two symbol
    /// planes as one visit, so a digit typed on 123 still arms the space bar on #+=.
    public mutating func didTogglePlane() {
        // Arming survives by design. The method exists so the toggle's call site names
        // the decision instead of silently skipping `didChangePage`.
    }
}
