import SwiftUI
import UIKit

/// Key colours for the extension.
///
/// The previous scheme filled letter keys with `.systemBackground` on a
/// `.secondarySystemBackground` field. In light mode that reads as a raised white keycap,
/// but in dark mode `.systemBackground` is pure black on a #1C1C1E field — so every
/// primary key rendered *darker* than its own background (~1.23:1) while the
/// `.systemGray4` modifier keys rendered lighter, inverting the hierarchy exactly.
///
/// These are dynamic colours: every provider resolves per appearance AND per the
/// Increase Contrast trait, which the old providers claimed to honour and never read.
/// Under Increase Contrast the ink roles (hint, trail, action) move further from their
/// surfaces and the engaged shift fill pulls further from a resting function key; the
/// primary keys stay the lightest element in every combination, the way the system
/// keyboard's do. `KeyPaletteContrastTests` holds every role to WCAG 2.2 AA.
enum KeyPalette {

    /// One grey per appearance and contrast level.
    private struct Grey {
        let normal: CGFloat
        let high: CGFloat
    }

    private static func grey(light: Grey, dark: Grey) -> UIColor {
        UIColor { traits in
            let pair = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(white: traits.accessibilityContrast == .high ? pair.high : pair.normal, alpha: 1)
        }
    }

    /// The keyboard field behind the keys.
    static let fieldColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.11, alpha: 1)
            : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
    }

    /// Primary keys: letters and symbols. Always the lightest surface.
    static let keycapColor = grey(
        light: Grey(normal: 1.0, high: 1.0),
        dark: Grey(normal: 0.32, high: 0.36)
    )

    /// Secondary keys: shift, backspace and the bottom chrome. Deliberately dimmer than
    /// `keycap` but still lighter than the field in both appearances.
    static let functionColor = grey(
        light: Grey(normal: 0.68, high: 0.66),
        dark: Grey(normal: 0.22, high: 0.17)
    )

    /// Shift when engaged — brighter than a resting function key in both appearances.
    /// In dark mode the engaged fill carries a white label at ~4.6:1, so Increase
    /// Contrast widens the gap by darkening the function key beside it rather than by
    /// brightening this one past the label's floor.
    static let activeColor = grey(
        light: Grey(normal: 0.52, high: 0.46),
        dark: Grey(normal: 0.46, high: 0.46)
    )

    /// The Latin hint under each glyph on the Rune·A face: 9pt semibold text on the
    /// learning face, held to the 4.5:1 body floor. `.secondary` resolved to ~3.4:1.
    static let hintColor = grey(
        light: Grey(normal: 0.40, high: 0.30),
        dark: Grey(normal: 0.82, high: 0.92)
    )

    /// The glide trail. Stroked translucent over the keycaps at `trailHeadOpacity`
    /// (the comet's newest segment) and `trailReducedMotionOpacity` (the plain line),
    /// so the colour is chosen for the composited result: dark over light keycaps,
    /// near-white over dark ones. `active` — which the trail used to borrow — sits
    /// between the two keycap greys and cleared 1.5:1 in dark mode.
    static let trailColor = grey(
        light: Grey(normal: 0.15, high: 0.0),
        dark: Grey(normal: 0.95, high: 1.0)
    )
    static let trailHeadOpacity: CGFloat = 0.70
    static let trailReducedMotionOpacity: CGFloat = 0.55

    /// The return key when the field names an action — search, go, send, done. Stock
    /// paints these as a tinted key with a white title. System blue under 13pt white
    /// is ~4.0:1 and fails AA, so this is a step darker than stock's in both
    /// appearances.
    static let actionColor = UIColor { traits in
        let high = traits.accessibilityContrast == .high
        if traits.userInterfaceStyle == .dark {
            return high
                ? UIColor(red: 0, green: 90 / 255, blue: 200 / 255, alpha: 1)
                : UIColor(red: 10 / 255, green: 108 / 255, blue: 228 / 255, alpha: 1)
        }
        return high
            ? UIColor(red: 0, green: 80 / 255, blue: 180 / 255, alpha: 1)
            : UIColor(red: 0, green: 100 / 255, blue: 220 / 255, alpha: 1)
    }
    static let actionTitleColor = UIColor.white

    static var field: Color { Color(uiColor: fieldColor) }
    static var keycap: Color { Color(uiColor: keycapColor) }
    static var function: Color { Color(uiColor: functionColor) }
    static var active: Color { Color(uiColor: activeColor) }
    static var hint: Color { Color(uiColor: hintColor) }
    static var trail: Color { Color(uiColor: trailColor) }
    static var action: Color { Color(uiColor: actionColor) }
    static var actionTitle: Color { Color(uiColor: actionTitleColor) }
}
