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
    /// Bumped by the controller when focus moves to a different host field. Per-field
    /// session state — shift provenance, the double-space window — resets on change.
    let fieldGeneration: Int
    /// Bumped on every host text change (including after this keyboard's own edits, once
    /// the proxy context has settled); shift is re-derived on change. Manual states
    /// survive by rule, so the re-derivation can only correct, never clobber.
    let hostTextGeneration: Int
    /// Live reads of the field being edited: what precedes the cursor, how it wants text
    /// capitalised, what its return key means, and whether Full Access was granted.
    let host: HostField
    /// Reports the visible page whenever something that changes the required height
    /// changes, so the container can re-reserve space.
    var onHeightInputsChanged: ((KeyboardMetrics.Page) -> Void)? = nil

    // Preferences are deliberately declared with inert defaults and loaded in exactly one
    // place — `loadPreferences()` on appear. Previously they were read both here and in
    // onAppear, with neither identifiable as authoritative.
    @State private var layoutMode: LayoutMode = .qwerty
    @State private var keyFaceStyle: KeyFaceStyle = .runeArt
    @State private var hapticsEnabled = true

    /// Shift plus its provenance. The pairing matters: an auto-armed shift re-derives
    /// from context on every call while a manual one is preserved, which is what breaks
    /// the ratchet the 2026-07-31 audit found (delete back into a word, shift stayed up).
    @State private var autoShift = AutoShift()
    @State private var page: KeyboardMetrics.Page = .letters

    /// When the last space was inserted, for the double-space-for-period shortcut. Nil
    /// after a substitution so a third space cannot produce a second period.
    @State private var lastSpaceAt: Date?

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
                    // Digits and punctuation move the cursor like any other insert, so
                    // they re-derive too — this was the one mutation path that skipped
                    // it and left shift stale on the 123 page.
                    onInsert: { insert($0); applyAutocapitalization() },
                    onBackspace: { deleteBackward(isRepeat: $0) }
                )
                .frame(height: pageHeight)
            case .letters:
                LetterPage(
                    layoutMode: layoutMode,
                    keyFaceStyle: keyFaceStyle,
                    shift: autoShift.state,
                    keyHeight: keyHeight,
                    hintSize: hintSize,
                    faceSize: letterFaceSize,
                    onLetter: insertLetter,
                    onShift: toggleShift,
                    onBackspace: { deleteBackward(isRepeat: $0) }
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
        .onChange(of: fieldGeneration) {
            // A different field: the old field's shift provenance and double-space
            // window are meaningless here. Start clean and derive for the new field.
            autoShift = AutoShift()
            lastSpaceAt = nil
            applyAutocapitalization()
        }
        .onChange(of: hostTextGeneration) {
            applyAutocapitalization()
        }
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
                insertSpace()
            }
            .frame(maxWidth: .infinity)

            // The cap names the host field's action -- Search, Send, Done -- rather than
            // always reading "return". The controller rebuilds this view when the focused
            // field changes; see KeyboardViewController.textDidChange.
            ChromeKeyButton(
                content: .text(ReturnKeyTitle.title(for: host.returnKeyType())),
                fontSize: 13,
                weight: .semibold,
                label: ReturnKeyTitle.accessibilityLabel(for: host.returnKeyType())
            ) {
                insert("\n")
                applyAutocapitalization()
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
        applyAutocapitalization()
    }

    private func insertLetter(_ letter: SleepTokenLetter) {
        insert(letter.englishInsert(shifted: autoShift.state.isUppercase))
        autoShift.didInsertLetter()
        applyAutocapitalization()
    }

    private func insert(_ text: String) {
        haptic()
        onInsert(text)
    }

    /// Space is the one character key with a rule attached: a second space typed quickly
    /// after a word replaces the first with ". ".
    private func insertSpace() {
        let elapsed = lastSpaceAt.map { Date().timeIntervalSince($0) } ?? .infinity

        if PeriodShortcut.shouldSubstitute(contextBefore: host.contextBefore(), sinceLastSpace: elapsed) {
            haptic()
            onDeleteBackward()
            onInsert(". ")
            lastSpaceAt = nil
        } else {
            insert(" ")
            lastSpaceAt = Date()
        }

        applyAutocapitalization()
    }

    /// `isRepeat` is false for the tap that begins a hold and true for every repeat after
    /// it, so a held delete does not fire twenty haptics a second.
    private func deleteBackward(isRepeat: Bool = false) {
        if !isRepeat { haptic() }
        onDeleteBackward()
        applyAutocapitalization()
    }

    private func toggleShift() {
        haptic()
        // Deliberately no re-derivation after the tap: cancelling an auto-armed shift
        // must stick until the next keystroke, and re-deriving here would instantly
        // re-arm it at the very sentence start the user just cancelled.
        autoShift.userTappedShift()
    }

    /// Re-reads the field and arms or releases shift accordingly. Runs after anything
    /// that moves the cursor — every insert path, delete, and return — never after a
    /// manual shift tap. Manual states pass through untouched; auto-armed ones are
    /// recomputed, so calling this can only ever correct, not clobber.
    private func applyAutocapitalization() {
        autoShift.apply(type: host.autocapitalization(), contextBefore: host.contextBefore())
    }

    private func haptic() {
        // Declaring RequestsOpenAccess is not enough: iOS drops feedback generator events
        // from a keyboard extension until the user actually grants Full Access, so this
        // has to check rather than assume. Without it the call is a silent no-op.
        guard hapticsEnabled, host.hasFullAccess() else { return }
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
    let onBackspace: (Bool) -> Void

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
        BackspaceKey(keyHeight: keyHeight, onBackspace: onBackspace)
    }
}

private struct SymbolsPage: View {
    let keyHeight: CGFloat
    let faceSize: CGFloat
    let onInsert: (String) -> Void
    let onBackspace: (Bool) -> Void

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
                BackspaceKey(keyHeight: keyHeight, onBackspace: onBackspace)
            }
        }
    }
}

// MARK: - Keycap chassis

/// The shared press feedback: highlight lands on touch-down, only the release fades
/// out, and Reduce Motion drops the scale. One definition serves the Button-based keys
/// (through KeyPressStyle) and the gesture-driven delete key alike — previously the
/// same four lines existed twice and had to be retuned in lockstep.
private struct PressAppearance: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isPressed ? 0.55 : 1)
            .scaleEffect(reduceMotion ? 1 : (isPressed ? 0.97 : 1))
            .animation(
                isPressed ? nil : (reduceMotion ? nil : .easeOut(duration: 0.08)),
                value: isPressed
            )
    }
}

private extension View {
    func pressAppearance(_ isPressed: Bool) -> some View {
        modifier(PressAppearance(isPressed: isPressed))
    }
}

/// The one delete key, shared by both pages so its icon, label, width, and repeat
/// behaviour cannot drift apart — the construction previously existed verbatim twice.
private struct BackspaceKey: View {
    let keyHeight: CGFloat
    let onBackspace: (Bool) -> Void

    var body: some View {
        RepeatingIconKeyButton(
            systemName: "delete.left",
            fill: KeyPalette.function,
            label: "Delete",
            action: onBackspace
        )
        .frame(width: KeyboardMetrics.functionKeyWidth, height: keyHeight)
    }
}

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

/// Delete, which repeats while held.
///
/// Built on a zero-distance drag rather than `Button` plus `onLongPressGesture`, because a
/// Button fires on release and this key has to fire on touch-down and keep firing until the
/// finger lifts. The drag also survives the finger sliding off the keycap, which is exactly
/// what happens when someone holds delete and their thumb relaxes.
private struct RepeatingIconKeyButton: View {
    let systemName: String
    let fill: Color
    let label: String
    /// `false` for the tap that starts the hold, `true` for every repeat after it, so the
    /// caller can fire feedback once rather than twenty times a second.
    let action: (Bool) -> Void

    /// `@GestureState`, not `@State`, and the difference is the whole point: its reset
    /// closure runs when the system CANCELS the touch (incoming call banner,
    /// Notification Center pulled over the keyboard) as well as when it ends. With
    /// `@State`, `onEnded` never arrived in those cases, the view stayed visible so
    /// `onDisappear` never fired either, and delete ran away at repeat rate while the
    /// user looked at the banner.
    @GestureState private var isPressed = false
    @State private var repeater: Task<Void, Never>?

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .keycap(fill: fill)
            .pressAppearance(isPressed)
            // The glyph does not fill the keycap, so without this the corners of the key
            // are visually part of it but not touchable.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
            )
            // All lifecycle flows from the one pressed flag: touch-down fires the first
            // delete and starts the repeater; end, cancellation, and (below) removal
            // all stop it. No path exists where the repeater outlives the touch.
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    action(false)
                    startRepeating()
                } else {
                    stopRepeating()
                }
            }
            .onDisappear(perform: stopRepeating)
            .accessibilityLabel(label)
            // A gesture-only view exposes no activate action of its own, and VoiceOver,
            // Switch Control, and Full Keyboard Access all depend on one. This restores
            // what the Button-based key provided: one deletion per activation.
            .accessibilityAction { action(false) }
            .accessibilityAddTraits([.isKeyboardKey, .isButton])
    }

    private func startRepeating() {
        repeater?.cancel()
        repeater = Task { @MainActor in
            // The gap that separates a tap from a hold. Cancelling during it leaves the
            // single delete already emitted on touch-down and nothing more.
            try? await Task.sleep(for: .seconds(KeyRepeat.initialDelay))

            var fired = 1
            while !Task.isCancelled {
                action(true)
                try? await Task.sleep(for: .seconds(KeyRepeat.interval(forRepeat: fired)))
                fired += 1
            }
        }
    }

    private func stopRepeating() {
        repeater?.cancel()
        repeater = nil
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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.pressAppearance(configuration.isPressed)
    }
}
