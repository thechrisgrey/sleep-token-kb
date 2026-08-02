import CoreGraphics

/// Single source of truth for keyboard geometry.
///
/// The SwiftUI key views lay themselves out from these values, and
/// `KeyboardViewController` reserves height by running the same arithmetic — so the
/// container can no longer disagree with its own contents. Previously the controller
/// held six hand-maintained literal totals while the real drivers lived privately in
/// `KeyboardRootView`, which under-allocated the grid layout by ~48pt and pushed its
/// top key row off the edge of the input view.
public enum KeyboardMetrics {

    // MARK: - Spacing scale

    /// Horizontal inset applied once at the root, so every row shares an edge.
    public static let edgeInset: CGFloat = 3
    /// Gap between keys within a row.
    public static let keyGap: CGFloat = 5
    /// Gap between rows, and between the last row and the bottom bar.
    public static let rowGap: CGFloat = 6
    public static let topPadding: CGFloat = 8
    public static let bottomPadding: CGFloat = 4
    /// The chrome bar shrinks alongside the keys in a compact height class: 32pt keys
    /// under a fixed 42pt bar inverted the size hierarchy between typing keys and
    /// chrome. It stays a shade taller than the compact keys because it hosts the
    /// widest touch targets.
    public static func bottomBarHeight(compact: Bool = false) -> CGFloat {
        compact ? 34 : 42
    }
    public static let keyCornerRadius: CGFloat = 6

    /// Width of shift and backspace. At least 44pt to meet the minimum touch target.
    public static let functionKeyWidth: CGFloat = 44

    // MARK: - Key heights

    public static let baseKeyHeight: CGFloat = 40
    /// Rune keys grow slightly when the Latin hint is shown beneath the glyph.
    public static let hintedKeyHeight: CGFloat = 44

    /// Landscape equivalents. Vertical room is scarce in a compact height class, so the
    /// keys shrink rather than the total being clamped — clamping the total is what let
    /// the container promise less space than the rows actually occupy.
    public static let compactBaseKeyHeight: CGFloat = 32
    public static let compactHintedKeyHeight: CGFloat = 36

    /// `compact` is the vertical size class being `.compact` (landscape on iPhone).
    /// The view and the view controller both derive it from the trait environment and
    /// both call this function, so they cannot disagree about how tall a key is.
    public static func keyHeight(
        style: KeyFaceStyle,
        compact: Bool = false
    ) -> CGFloat {
        let hinted = style.showsLatinHint
        if compact {
            return hinted ? compactHintedKeyHeight : compactBaseKeyHeight
        }
        return hinted ? hintedKeyHeight : baseKeyHeight
    }

    // MARK: - Row counts

    /// Which page the keyboard is currently showing.
    public enum Page: String, CaseIterable, Sendable {
        case letters
        case symbols
        case symbolsAlt
        case emoji
    }

    /// Everything the container must know to reserve height, as one value over one
    /// channel. Previously the page travelled a callback while the layout mode was
    /// re-read from UserDefaults inside the controller — two transports for inputs to
    /// a single derivation, which made it impossible to exercise end to end.
    public struct HeightInputs: Equatable, Sendable {
        public let page: Page
        public let mode: LayoutMode

        public init(page: Page, mode: LayoutMode) {
            self.page = page
            self.mode = mode
        }
    }

    /// Number of full-height rows the page renders.
    ///
    /// QWERTY carries shift and backspace inline on its last row; the grid and symbols
    /// pages each add a dedicated row for them, which the old literal table never counted.
    public static func rowCount(page: Page, mode: LayoutMode) -> Int {
        switch page {
        case .symbols, .symbolsAlt:
            // Delete rides inline on row three the way stock does it, so these pages no
            // longer need a row of their own for a single key.
            return KeyboardLayout.symbolRows.count
        case .emoji:
            // The emoji grid scrolls, so it never drives the keyboard's height: it takes
            // exactly what the letters page for this layout already occupies.
            return rowCount(page: .letters, mode: mode)
        case .letters:
            switch mode {
            case .qwerty: return KeyboardLayout.qwertyRows.count
            case .grid: return KeyboardLayout.gridRows.count + 1
            }
        }
    }

    /// Row height for a page. Only letter keycaps can carry a Latin hint beneath the
    /// glyph, so only the letters page grows with the key face — symbol and emoji cells
    /// stay at the base height. Letting the face resize every page was one of the two
    /// reasons the keyboard changed size mid-session.
    public static func keyHeight(
        page: Page,
        style: KeyFaceStyle,
        compact: Bool = false
    ) -> CGFloat {
        switch page {
        case .letters:
            return keyHeight(style: style, compact: compact)
        case .symbols, .symbolsAlt, .emoji:
            return compact ? compactBaseKeyHeight : baseKeyHeight
        }
    }

    /// Height of just the key rows, excluding the bottom bar and outer padding.
    /// The key pages pin themselves to this so their GeometryReader cannot expand.
    public static func pageHeight(
        page: Page,
        mode: LayoutMode,
        style: KeyFaceStyle,
        compact: Bool = false
    ) -> CGFloat {
        let rows = CGFloat(rowCount(page: page, mode: mode))
        let height = keyHeight(page: page, style: style, compact: compact)
        return rows * height + max(rows - 1, 0) * rowGap
    }

    /// Exact height the SwiftUI content needs, which is what the controller reserves.
    public static func contentHeight(
        page: Page,
        mode: LayoutMode,
        style: KeyFaceStyle,
        compact: Bool = false
    ) -> CGFloat {
        let rows = pageHeight(page: page, mode: mode, style: style, compact: compact)
        return topPadding + rows + rowGap + bottomBarHeight(compact: compact) + bottomPadding
    }

    /// Width of one letter key, so every row shares a unit and columns line up.
    /// Derived from the widest row (10 keys) rather than each row's own count.
    public static func keyUnit(availableWidth: CGFloat, keysPerRow: Int = 10) -> CGFloat {
        let gaps = CGFloat(max(keysPerRow - 1, 0)) * keyGap
        return max(0, (availableWidth - gaps) / CGFloat(max(keysPerRow, 1)))
    }

    /// Half-key inset that centres a 9-key home row under a 10-key top row.
    public static func homeRowInset(keyUnit: CGFloat) -> CGFloat {
        (keyUnit + keyGap) / 2
    }

    /// Height the container reserves, whichever page is showing and whichever key face
    /// is selected.
    ///
    /// Stock keyboards do not resize when you tap 123; ours grew 46pt, because the
    /// controller reserved height for the current page only. Reserving the tallest
    /// combination up front costs a little empty space above the shorter pages — which
    /// is what stock does too — and buys a keyboard that never moves under the thumb.
    public static func reservedHeight(mode: LayoutMode, compact: Bool = false) -> CGFloat {
        var tallest: CGFloat = 0
        for page in Page.allCases {
            for style in KeyFaceStyle.allCases {
                tallest = max(tallest, contentHeight(
                    page: page, mode: mode, style: style, compact: compact
                ))
            }
        }
        return tallest
    }

    /// Tallest height any key style can need for this page, so cycling the key face
    /// never leaves the already-visible rows clipped mid-transition.
    public static func maxContentHeight(
        page: Page,
        mode: LayoutMode,
        compact: Bool = false
    ) -> CGFloat {
        var tallest: CGFloat = 0
        for style in KeyFaceStyle.allCases {
            tallest = max(tallest, contentHeight(
                page: page, mode: mode, style: style, compact: compact
            ))
        }
        return tallest
    }
}
