import Foundation

/// Where the space bar leaves the keyboard.
///
/// Stock iOS treats 123 and #+= as a detour rather than a destination: type a digit or a
/// mark, press space, and the letters come back on their own. Ours stranded the user on
/// symbols after every "?" and "!", so finishing a sentence cost a tap on ABC that the
/// system keyboard has never charged.
///
/// The return is *armed by the first keystroke of a visit*, not by arrival. Measured
/// against the system keyboard on iOS 26, driving the real thing rather than reasoning
/// about it: `123 space` stays on 123, `123 5 space` returns to letters, and so does
/// `123 5 delete space` — so what arms it is the keystroke, not the text it left behind.
/// The arming survives the 123 <-> #+= toggle, which stock counts as one visit, and
/// leaving for letters and coming back disarms it again.
public enum PageAfterSpace {

    /// The page that should be showing once this space has landed.
    ///
    /// - Parameters:
    ///   - current: the page the space was typed on.
    ///   - typedSinceEntering: whether a character has been typed since this visit to the
    ///     symbol planes began. False for the space that arrives before any keystroke —
    ///     the "meet me at " before the 5:30 — which stock leaves on 123 so the digits
    ///     stay one tap away.
    ///   - numberPadField: whether the host field asked for a number pad. There the
    ///     symbols page is the destination — the field wants digits — so the rule stands
    ///     down rather than throwing the user onto letters they cannot use.
    public static func page(
        from current: KeyboardMetrics.Page,
        typedSinceEntering: Bool,
        numberPadField: Bool
    ) -> KeyboardMetrics.Page {
        guard !numberPadField else { return current }

        switch current {
        case .symbols, .symbolsAlt:
            return typedSinceEntering ? .letters : current
        case .letters:
            return current
        case .emoji:
            // Emoji is a destination too: stock's emoji keyboard keeps its grid when you
            // type a space and leaves only on the explicit ABC key.
            return current
        }
    }
}
