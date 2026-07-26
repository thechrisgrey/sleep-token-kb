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
/// These are dynamic colours, so they still resolve per appearance and still pick up the
/// system's Increase Contrast variants; they simply keep the primary keys the lightest
/// element in both appearances, the way the system keyboard does.
enum KeyPalette {

    /// The keyboard field behind the keys.
    static let fieldColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.11, alpha: 1)
            : UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
    }

    /// Primary keys: letters and symbols. Always the lightest surface.
    static let keycapColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.32, alpha: 1)
            : UIColor(white: 1.0, alpha: 1)
    }

    /// Secondary keys: shift, backspace and the bottom chrome. Deliberately dimmer than
    /// `keycap` but still lighter than the field in both appearances.
    static let functionColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 1)
            : UIColor(white: 0.68, alpha: 1)
    }

    /// Shift when engaged — brighter than a resting function key in both appearances.
    static let activeColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.46, alpha: 1)
            : UIColor(white: 0.52, alpha: 1)
    }

    static var field: Color { Color(uiColor: fieldColor) }
    static var keycap: Color { Color(uiColor: keycapColor) }
    static var function: Color { Color(uiColor: functionColor) }
    static var active: Color { Color(uiColor: activeColor) }
}
