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
    //
    // These are not chosen numbers. Every one of them was measured off the stock iOS 26
    // English keyboard, screenshotted at native scale on four iPhone widths — 390, 402,
    // 420 and 440pt — and read back in points. All four agree exactly, and the row
    // arithmetic below closes to the pixel on all four:
    //
    //     screenWidth == 2 * edgeInset + 10 * keyUnit + 9 * keyGap
    //
    // A keyboard extension is a guest inside other apps, and the muscle memory it
    // inherits belongs to the system keyboard. Typing on ours used to mean typing on a
    // grid whose row pitch was 46pt against stock's 54pt — by the third row a thumb was
    // 16pt off its remembered target, which is the "one step taller than the rest"
    // feeling that made this measurement necessary. Do not retune these by eye.

    /// Horizontal inset applied once at the root, so every row shares an edge.
    public static let edgeInset: CGFloat = 6.5
    /// Gap between keys within a row.
    public static let keyGap: CGFloat = 6
    /// Gap between rows, and between the last row and the bottom bar.
    ///
    /// Stock tightens this in a compact height class — 8pt against 11 — rather than
    /// letting a landscape keyboard eat the screen. A function, not a constant, so the
    /// compiler names every call site that has to decide which one it means.
    public static func rowGap(compact: Bool = false) -> CGFloat {
        compact ? 8 : 11
    }
    public static let topPadding: CGFloat = 8
    public static let bottomPadding: CGFloat = 4
    /// Stock's bottom row — 123, space, return — is a key row like any other, at the
    /// same height and behind the same row gap, so the regular value is `baseKeyHeight`
    /// exactly. (Stock then hangs emoji and dictation below it on a strip of their own;
    /// ours fold into this one bar, which is why it is a bar and not a fourth row.)
    ///
    /// The chrome bar shrinks alongside the keys in a compact height class: 32pt keys
    /// under a fixed 42pt bar inverted the size hierarchy between typing keys and
    /// chrome. It stays a shade taller than the compact keys because it hosts the
    /// widest touch targets.
    public static func bottomBarHeight(compact: Bool = false) -> CGFloat {
        compact ? 30 : 43
    }

    /// The candidate strip above the keys.
    ///
    /// Reserved unconditionally, even when there is nothing to show. The alternative —
    /// growing the keyboard only when a correction exists — would make it jump under the
    /// thumb mid-word, which is the exact behaviour the constant-height work removed.
    public static func suggestionBarHeight(compact: Bool = false) -> CGFloat {
        compact ? 34 : 40
    }
    public static let keyCornerRadius: CGFloat = 6

    /// The 44pt floor every touch target has to clear. Chrome that is not part of the
    /// letter grid — the bottom bar's page key, the options panel, the emoji strip's
    /// delete — sizes itself against this rather than against a key unit it has no
    /// business knowing.
    public static let minimumTouchTarget: CGFloat = 44

    /// Width of shift and backspace.
    ///
    /// Derived, because stock derives it: the function row has to tile the same ten
    /// units as the row above it, so shift and delete each swallow one key plus the two
    /// gaps around it. Measured against stock this lands within a point on every iPhone
    /// width (44.3 / 45.5 / 47.3 / 49.3 against 44.0 / 45.5 / 48.0 / 50.3) where the old
    /// flat 44pt literal was 5pt narrow on a Pro Max and left the key floating inboard
    /// of the keyboard's own edge.
    public static func functionKeyWidth(keyUnit: CGFloat) -> CGFloat {
        keyUnit + 2 * keyGap
    }

    /// The gap stock leaves between a function key and the letters beside it — wider
    /// than the gap between two letters, so a thumb aiming at Z has room to miss shift.
    /// Falls out of the tiling identity above: it is exactly the slack left over.
    public static func functionKeyFlank(keyUnit: CGFloat) -> CGFloat {
        max(0, (keyUnit - keyGap) / 2)
    }

    /// What a row's own `HStack` must add between a function key and the letter block,
    /// given the layout already contributes one `keyGap` on each side of it.
    public static func functionKeySpacer(keyUnit: CGFloat) -> CGFloat {
        max(0, functionKeyFlank(keyUnit: keyUnit) - 2 * keyGap)
    }

    // MARK: - Key heights

    /// Stock's portrait keycap. Measured 43pt on every iPhone up to 402pt wide; the
    /// 420pt and 440pt bodies (Air, Pro Max) take 45pt instead. We hold one height for
    /// every width, so the two largest phones run 2pt under stock — a deliberate trade
    /// against threading a layout width into a height the container has to reserve
    /// before it has been laid out.
    public static let baseKeyHeight: CGFloat = 43
    /// Rune keys grow slightly when the Latin hint is shown beneath the glyph.
    public static let hintedKeyHeight: CGFloat = 47

    /// Landscape equivalents. Vertical room is scarce in a compact height class, so the
    /// keys shrink rather than the total being clamped — clamping the total is what let
    /// the container promise less space than the rows actually occupy. Stock lands on
    /// 27.5pt keys behind an 8pt row gap in landscape, on both a 402pt and a 440pt body.
    public static let compactBaseKeyHeight: CGFloat = 27.5
    public static let compactHintedKeyHeight: CGFloat = 31.5

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
        return rows * height + max(rows - 1, 0) * rowGap(compact: compact)
    }

    /// Exact height the SwiftUI content needs, which is what the controller reserves.
    public static func contentHeight(
        page: Page,
        mode: LayoutMode,
        style: KeyFaceStyle,
        compact: Bool = false
    ) -> CGFloat {
        let rows = pageHeight(page: page, mode: mode, style: style, compact: compact)
        let gap = rowGap(compact: compact)
        return topPadding
            + suggestionBarHeight(compact: compact) + gap
            + rows + gap
            + bottomBarHeight(compact: compact)
            + bottomPadding
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
