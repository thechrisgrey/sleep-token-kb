import SwiftUI
import UIKit

/// Simple fan keyboard: ritual or ABC keycaps, always types normal English.
/// For actual rune *text*, open Rune Pad in the host app and copy as image.
///
/// Text entry is owned by the controller and reached through closures, so the proxy is
/// read live at the moment of the keystroke rather than snapshotted into this struct.
struct KeyboardRootView: View {
    let onInsert: (String) -> Void
    let onDeleteBackward: () -> Void
    let onNextKeyboard: () -> Void
    let needsInputModeSwitchKey: Bool
    /// Reports the visible page whenever something that changes the required height
    /// changes, so the container can re-reserve space.
    var onHeightInputsChanged: ((KeyboardMetrics.Page) -> Void)? = nil

    // Preferences are deliberately declared with inert defaults and loaded in exactly one
    // place — `loadPreferences()` on appear. Previously they were read both here and in
    // onAppear, with neither identifiable as authoritative.
    @State private var layoutMode: LayoutMode = .qwerty
    @State private var keyFaceStyle: KeyFaceStyle = .runeArt
    @State private var hapticsEnabled = true

    @State private var shift: ShiftState = .off
    @State private var page: KeyboardMetrics.Page = .letters

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Scaled within the keyboard's fixed height budget, clamped at the root so the
    /// extension cannot grow unboundedly.
    @ScaledMetric(relativeTo: .caption2) private var hintSize: CGFloat = 9
    @ScaledMetric(relativeTo: .body) private var letterFaceSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var symbolFaceSize: CGFloat = 16

    /// One generator for the life of the extension. As an instance property it was
    /// re-allocated with every root view, so the object `prepare()` warmed was discarded
    /// before it ever fired.
    private static let impact = UIImpactFeedbackGenerator(style: .light)

    private var isCompact: Bool { verticalSizeClass == .compact }

    private var keyHeight: CGFloat {
        KeyboardMetrics.keyHeight(style: keyFaceStyle, compact: isCompact)
    }

    private var pageHeight: CGFloat {
        KeyboardMetrics.pageHeight(
            page: page,
            mode: layoutMode,
            style: keyFaceStyle,
            compact: isCompact
        )
    }

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowGap) {
            switch page {
            case .symbols:
                SymbolsPage(
                    keyHeight: keyHeight,
                    faceSize: symbolFaceSize,
                    onInsert: insert,
                    onBackspace: deleteBackward
                )
                .frame(height: pageHeight)
            case .letters:
                LetterPage(
                    layoutMode: layoutMode,
                    keyFaceStyle: keyFaceStyle,
                    shift: shift,
                    keyHeight: keyHeight,
                    hintSize: hintSize,
                    faceSize: letterFaceSize,
                    onLetter: insertLetter,
                    onShift: toggleShift,
                    onBackspace: deleteBackward
                )
                .frame(height: pageHeight)
            }

            bottomBar
                .frame(height: KeyboardMetrics.bottomBarHeight)
        }
        .padding(.horizontal, KeyboardMetrics.edgeInset)
        .padding(.top, KeyboardMetrics.topPadding)
        .padding(.bottom, KeyboardMetrics.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(KeyPalette.field)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .onAppear(perform: loadPreferences)
    }

    // MARK: - Bottom chrome
    //
    // One convention across all three switch keys: the title names the DESTINATION, and
    // the accessibility label reads "Switch to <destination>". No two titles can collide
    // — the style key names a style ("Rune"/"Aa"), the page key names an alphabet.

    private var bottomBar: some View {
        HStack(spacing: KeyboardMetrics.keyGap) {
            if needsInputModeSwitchKey {
                ChromeKeyButton(
                    content: .symbol("globe"),
                    weight: .medium,
                    label: "Next keyboard",
                    action: onNextKeyboard
                )
                .frame(width: 38)
            }

            ChromeKeyButton(
                content: .text(layoutMode.next.shortTitle),
                fontSize: 12,
                weight: .semibold,
                label: "Switch to \(layoutMode.next.accessibilityLabel)"
            ) {
                haptic()
                layoutMode = layoutMode.next
                KeyboardPreferences.layoutMode = layoutMode
                onHeightInputsChanged?(page)
            }
            .frame(width: 54)

            // Cycles the key face: runes -> runes with Latin hints -> plain ABC.
            // Text is always English regardless of the face.
            ChromeKeyButton(
                content: .text(keyFaceStyle.next.shortTitle),
                fontSize: 12,
                weight: .semibold,
                label: "Switch to \(keyFaceStyle.next.title)"
            ) {
                haptic()
                keyFaceStyle = keyFaceStyle.next
                KeyboardPreferences.keyFaceStyle = keyFaceStyle
                onHeightInputsChanged?(page)
            }
            .frame(width: 50)

            ChromeKeyButton(
                content: .text(page == .symbols ? "ABC" : "123"),
                fontSize: 14,
                weight: .semibold,
                label: page == .symbols ? "Switch to letters" : "Switch to numbers"
            ) {
                haptic()
                page = (page == .symbols) ? .letters : .symbols
                onHeightInputsChanged?(page)
            }
            .frame(width: 44)

            // The space bar is a primary key, so it takes the primary keycap fill.
            ChromeKeyButton(
                content: .text("space"),
                fontSize: 14,
                weight: .regular,
                label: "Space",
                fill: KeyPalette.keycap
            ) {
                insert(" ")
            }
            .frame(maxWidth: .infinity)

            ChromeKeyButton(
                content: .text("return"),
                fontSize: 13,
                weight: .semibold,
                label: "Return"
            ) {
                insert("\n")
            }
            .frame(width: 56)
        }
    }

    // MARK: - Actions

    private func loadPreferences() {
        layoutMode = KeyboardPreferences.layoutMode
        keyFaceStyle = KeyboardPreferences.keyFaceStyle
        hapticsEnabled = KeyboardPreferences.hapticsEnabled
        if hapticsEnabled { Self.impact.prepare() }
        onHeightInputsChanged?(page)
    }

    private func insertLetter(_ letter: SleepTokenLetter) {
        insert(letter.englishInsert(shifted: shift.isUppercase))
        shift = shift.afterInsert()
    }

    private func insert(_ text: String) {
        haptic()
        onInsert(text)
    }

    private func deleteBackward() {
        haptic()
        onDeleteBackward()
    }

    private func toggleShift() {
        haptic()
        shift = shift.toggled()
    }

    private func haptic() {
        guard hapticsEnabled else { return }
        Self.impact.impactOccurred(intensity: 0.7)
        // Re-arm for the next keystroke; a single warm-up only covers the first tap.
        Self.impact.prepare()
    }
}

// MARK: - Pages

private struct LetterPage: View {
    let layoutMode: LayoutMode
    let keyFaceStyle: KeyFaceStyle
    let shift: ShiftState
    let keyHeight: CGFloat
    let hintSize: CGFloat
    let faceSize: CGFloat
    let onLetter: (SleepTokenLetter) -> Void
    let onShift: () -> Void
    let onBackspace: () -> Void

    private var rows: [[SleepTokenLetter]] {
        layoutMode == .qwerty ? KeyboardLayout.qwertyRows : KeyboardLayout.gridRows
    }

    var body: some View {
        // One GeometryReader for the page (not per key) so every row shares a key unit
        // and columns line up. Height is pinned by the caller, so it cannot expand.
        GeometryReader { geo in
            let unit = KeyboardMetrics.keyUnit(availableWidth: geo.size.width)
            VStack(spacing: KeyboardMetrics.rowGap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: KeyboardMetrics.keyGap) {
                        if layoutMode == .qwerty && index == rows.count - 1 {
                            shiftKey
                        }

                        ForEach(row) { letter in
                            LetterKeyButton(
                                letter: letter,
                                keyFaceStyle: keyFaceStyle,
                                keyHeight: keyHeight,
                                hintSize: hintSize,
                                faceSize: faceSize,
                                fixedWidth: layoutMode == .qwerty ? unit : nil,
                                action: { onLetter(letter) }
                            )
                            .equatable()
                        }

                        if layoutMode == .qwerty && index == rows.count - 1 {
                            backspaceKey
                        }
                    }
                    // Centre the 9-key home row under the 10-key top row. The old flat
                    // 12pt literal could not be correct on more than one screen width.
                    .padding(
                        .horizontal,
                        layoutMode == .qwerty && index == rows.count - 2
                            ? KeyboardMetrics.homeRowInset(keyUnit: unit)
                            : 0
                    )
                }

                if layoutMode == .grid {
                    HStack(spacing: KeyboardMetrics.keyGap) {
                        shiftKey
                        Spacer(minLength: 0)
                        backspaceKey
                    }
                    .frame(height: keyHeight)
                }
            }
            .frame(width: geo.size.width, alignment: .top)
        }
    }

    private var shiftKey: some View {
        IconKeyButton(
            systemName: shift.symbolName,
            fill: shift == .off ? KeyPalette.function : KeyPalette.active,
            label: "Shift",
            value: shift.accessibilityValue,
            selected: shift != .off,
            action: onShift
        )
        .frame(width: KeyboardMetrics.functionKeyWidth, height: keyHeight)
    }

    private var backspaceKey: some View {
        IconKeyButton(
            systemName: "delete.left",
            fill: KeyPalette.function,
            label: "Delete",
            action: onBackspace
        )
        .frame(width: KeyboardMetrics.functionKeyWidth, height: keyHeight)
    }
}

private struct SymbolsPage: View {
    let keyHeight: CGFloat
    let faceSize: CGFloat
    let onInsert: (String) -> Void
    let onBackspace: () -> Void

    private var rows: [[String]] { KeyboardLayout.symbolRows }

    var body: some View {
        VStack(spacing: KeyboardMetrics.rowGap) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: KeyboardMetrics.keyGap) {
                    ForEach(rows[index], id: \.self) { symbol in
                        SymbolKeyButton(symbol: symbol, faceSize: faceSize) {
                            onInsert(symbol)
                        }
                        .frame(height: keyHeight)
                    }
                }
            }
            HStack {
                Spacer(minLength: 0)
                IconKeyButton(
                    systemName: "delete.left",
                    fill: KeyPalette.function,
                    label: "Delete",
                    action: onBackspace
                )
                .frame(width: KeyboardMetrics.functionKeyWidth, height: keyHeight)
            }
        }
    }
}

// MARK: - Keycap chassis

/// The one keycap shape. Four key structs previously re-declared it independently.
private struct KeycapBackground: ViewModifier {
    let fill: Color

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: KeyboardMetrics.keyCornerRadius, style: .continuous)
                .fill(fill)
        )
    }
}

private extension View {
    func keycap(fill: Color) -> some View {
        modifier(KeycapBackground(fill: fill))
    }
}

// MARK: - Keys

private struct LetterKeyButton: View, Equatable {
    let letter: SleepTokenLetter
    let keyFaceStyle: KeyFaceStyle
    let keyHeight: CGFloat
    let hintSize: CGFloat
    let faceSize: CGFloat
    let fixedWidth: CGFloat?
    let action: () -> Void

    /// Compares only the value inputs, ignoring the closure — which is freshly allocated
    /// per key per render. Without this a shift tap repaints all 26 glyph keys.
    static func == (lhs: LetterKeyButton, rhs: LetterKeyButton) -> Bool {
        lhs.letter == rhs.letter
            && lhs.keyFaceStyle == rhs.keyFaceStyle
            && lhs.keyHeight == rhs.keyHeight
            && lhs.hintSize == rhs.hintSize
            && lhs.faceSize == rhs.faceSize
            && lhs.fixedWidth == rhs.fixedWidth
    }

    var body: some View {
        Button(action: action) {
            face
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .keycap(fill: KeyPalette.keycap)
        }
        .buttonStyle(KeyPressStyle())
        .frame(width: fixedWidth, height: keyHeight)
        // The Button is the sole accessibility element: SymbolGlyphView carries its own
        // label and hint for the host app's chart, which would otherwise make the two key
        // faces announce differently for the same letter.
        .accessibilityLabel(letter.upperLatin)
        .accessibilityAddTraits(.isKeyboardKey)
    }

    @ViewBuilder
    private var face: some View {
        switch keyFaceStyle {
        case .runeArt:
            SymbolGlyphView(letter: letter)
                .accessibilityHidden(true)
                .padding(.vertical, 6)
        case .runeHints:
            VStack(spacing: 1) {
                SymbolGlyphView(letter: letter)
                    .accessibilityHidden(true)
                Text(letter.upperLatin)
                    .font(.system(size: hintSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 5)
        case .letters:
            Text(letter.upperLatin)
                .font(.system(size: faceSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
        }
    }
}

private struct SymbolKeyButton: View {
    let symbol: String
    let faceSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: faceSize, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // A digit is a character key, not a function key: it takes the primary
                // keycap fill, leaving the dimmer fill to mean "modifier".
                .keycap(fill: KeyPalette.keycap)
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityAddTraits(.isKeyboardKey)
    }
}

/// Shift and backspace, which previously differed only in four literals.
private struct IconKeyButton: View {
    let systemName: String
    let fill: Color
    let label: String
    var value: String = ""
    var selected: Bool = false
    let action: () -> Void

    private var traits: AccessibilityTraits {
        selected ? [.isKeyboardKey, .isSelected] : [.isKeyboardKey]
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .keycap(fill: fill)
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(label)
        .accessibilityValue(value)
        .accessibilityAddTraits(traits)
    }
}

/// Bottom-bar keys. These are navigation actions rather than character emitters, so they
/// deliberately do NOT take `.isKeyboardKey` — VoiceOver keeps its confirm-before-acting
/// behaviour for them.
private struct ChromeKeyButton: View {
    enum Content {
        case text(String)
        case symbol(String)
    }

    let content: Content
    var fontSize: CGFloat = 14
    var weight: Font.Weight = .regular
    let label: String
    var fill: Color = KeyPalette.function
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case .symbol(let name):
                    Image(systemName: name)
                        .font(.body.weight(weight))
                case .text(let title):
                    Text(title)
                        .font(.system(size: fontSize, weight: weight, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .keycap(fill: fill)
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(label)
    }
}

private struct KeyPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            // Highlight lands immediately on touch-down; only the release fades out.
            .animation(
                configuration.isPressed ? nil : (reduceMotion ? nil : .easeOut(duration: 0.08)),
                value: configuration.isPressed
            )
    }
}
