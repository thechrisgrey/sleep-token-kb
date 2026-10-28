import SwiftUI
import UIKit

/// The letters page: both layouts rendered from the validated tables, with the glide
/// gesture layered over the keys.
///
/// Its own file for the same reason EmojiPage and SymbolsPage left KeyboardRootView:
/// the inputs are plain values and closures with no root-view state, and the glide
/// session is the page's own `@State`. The keycap chassis it draws with (LetterKeyButton,
/// IconKeyButton, BackspaceKey, the keycap and press modifiers) stays in
/// KeyboardRootView.swift beside the other keys, internal rather than private.
struct LetterPage: View {
    let layoutMode: LayoutMode
    let keyFaceStyle: KeyFaceStyle
    let shift: ShiftState
    let keyHeight: CGFloat
    let hintSize: CGFloat
    let faceSize: CGFloat
    /// Glide typing: QWERTY-only, off under VoiceOver, additive over the buttons.
    let glideEnabled: Bool
    let onLetter: (SleepTokenLetter) -> Void
    let onShift: () -> Void
    /// The named accessibility action on the shift key — the assistive route into
    /// caps lock now that the slow tap releases instead of cycling.
    let onCapsLock: () -> Void
    let onBackspace: (Bool) -> Void
    let onGlide: (_ trace: [CGPoint], _ availableWidth: CGFloat) -> Void

    @State private var glide = GlideSession()
    /// Keeps taps suppressed one runloop tick past lift, so the origin key's
    /// Button cannot fire on the same touch-up. During the drag itself the
    /// suppression rides `isGliding`.
    @State private var suppressesTaps = false
    /// True while the finger is down in THIS gesture. `@GestureState`, not
    /// `@State`, and the difference is the whole point (see BackspaceKey): its
    /// reset also runs when the system CANCELS the touch, so a call banner
    /// mid-glide cannot wedge the keyboard.
    @GestureState private var isGliding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Read here rather than passed, exactly as KeyboardRootView reads it: both sit in
    /// one hosting controller's trait environment, so there is only ever one answer —
    /// and the row pitch this page draws with must be the one height was reserved for.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var compact: Bool { verticalSizeClass == .compact }

    private var rows: [[SleepTokenLetter]] {
        layoutMode == .qwerty ? KeyboardLayout.qwertyRows : KeyboardLayout.gridRows
    }

    var body: some View {
        // One GeometryReader for the page (not per key) so every row shares a key unit
        // and columns line up. Height is pinned by the caller, so it cannot expand.
        GeometryReader { geo in
            let unit = KeyboardMetrics.keyUnit(availableWidth: geo.size.width)
            // The grid's rows are 9, 9 and 8 keys: one 9-key unit for all three, so the
            // columns align and the short s–z row centres under them. Dividing each
            // row's width by its own count made the last row's keys 12% wider.
            let gridUnit = KeyboardMetrics.keyUnit(availableWidth: geo.size.width, keysPerRow: 9)
            VStack(spacing: KeyboardMetrics.rowGap(compact: compact)) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: KeyboardMetrics.keyGap) {
                        if layoutMode == .qwerty && index == rows.count - 1 {
                            shiftKey(unit: unit)
                            // Stock seats shift and delete flush against the keyboard's
                            // own edge and leaves a wider gap before the letters than
                            // between them, so a thumb aiming at Z has room to miss.
                            // The HStack already contributes one keyGap either side of
                            // this spacer, so it carries only the remainder.
                            Color.clear
                                .frame(width: KeyboardMetrics.functionKeySpacer(keyUnit: unit))
                        }

                        ForEach(row) { letter in
                            LetterKeyButton(
                                letter: letter,
                                keyFaceStyle: keyFaceStyle,
                                // Rune art carries no case, so its VISUAL face is pinned
                                // to false. The spoken case below is never pinned: the
                                // label must tell the truth on every face, which costs
                                // rune art the same shift-change repaint the Latin
                                // faces already pay.
                                shifted: keyFaceStyle == .runeArt ? false : shift.isUppercase,
                                spokenUppercase: shift.isUppercase,
                                keyHeight: keyHeight,
                                hintSize: hintSize,
                                faceSize: faceSize,
                                fixedWidth: layoutMode == .qwerty ? unit : gridUnit,
                                action: {
                                    guard !(isGliding || suppressesTaps) else { return }
                                    onLetter(letter)
                                }
                            )
                            .equatable()
                        }

                        if layoutMode == .qwerty && index == rows.count - 1 {
                            Color.clear
                                .frame(width: KeyboardMetrics.functionKeySpacer(keyUnit: unit))
                            backspaceKey(unit: unit)
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
                        shiftKey(unit: unit)
                        Spacer(minLength: 0)
                        backspaceKey(unit: unit)
                    }
                    .frame(height: keyHeight)
                }
            }
            .frame(width: geo.size.width, alignment: .top)
            .overlay {
                if glide.isActive {
                    GlideTrailView(points: glide.points, reduceMotion: reduceMotion)
                        .allowsHitTesting(false)
                }
            }
            .simultaneousGesture(glideGesture(width: geo.size.width), including: glideActive ? .all : .subviews)
            .onChange(of: isGliding) { _, active in
                // @GestureState's reset is the only signal a CANCELLED touch
                // gives us: falling while the session is still active means no
                // onEnded came — discard the glide, clear the trail. This is
                // the spec's cancellation clause, and GlideSession.cancel's
                // one production caller.
                guard !active, glide.isActive else { return }
                glide.cancel()
                suppressesTaps = false
            }
        }
    }

    private var glideActive: Bool {
        glideEnabled && layoutMode == .qwerty && !UIAccessibility.isVoiceOverRunning
    }

    private func glideGesture(width: CGFloat) -> some Gesture {
        let unit = KeyboardMetrics.keyUnit(availableWidth: width)
        return DragGesture(minimumDistance: unit / 2, coordinateSpace: .local)
            .updating($isGliding) { _, state, _ in state = true }
            .onChanged { value in
                guard glideActive else { return }
                if glide.points.first != value.startLocation {
                    // A glide must BEGIN on a letter: a thumb drifting off a held
                    // backspace or shift is not a word. The gate and its radius live
                    // in GlideGate, beside the tap floor below.
                    guard GlideGate.beginsOnLetter(
                        at: value.startLocation, centers: centers(width: width), keyUnit: unit
                    ) else { return }
                }
                suppressesTaps = true
                glide.extend(start: value.startLocation, to: value.location)
            }
            .onEnded { value in
                guard glideActive, glide.isActive else { return }
                let trace = glide.finish(at: value.location)
                // The drag threshold above is half a key; the origin Button's tap is
                // already suppressed. A thumb that rolled less than a key's width never
                // meant a word, so it types the key under the lift instead of handing
                // an 18pt stub to the decoder, which used to find "ty" and "sd" in it.
                if let letter = GlideGate.tapLikeLetter(trace: trace, centers: centers(width: width), keyUnit: unit) {
                    onLetter(letter)
                } else {
                    onGlide(trace, width)
                }
                // Release tap suppression on the next runloop tick, after the
                // origin Button has had its chance to (not) fire for this touch.
                Task { @MainActor in suppressesTaps = false }
            }
    }

    /// The same centres the decoder scores against, for the gates at both ends.
    private func centers(width: CGFloat) -> [SleepTokenLetter: CGPoint] {
        KeyCenters.qwerty(availableWidth: width, keyHeight: keyHeight, compact: compact)
    }

    private func shiftKey(unit: CGFloat) -> some View {
        IconKeyButton(
            systemName: shift.symbolName,
            fill: shift == .off ? KeyPalette.function : KeyPalette.active,
            label: "Shift",
            value: shift.accessibilityValue,
            selected: shift != .off,
            action: onShift
        )
        // The double tap that engages caps lock is two activations inside 0.35s —
        // not a gesture VoiceOver or Switch Control users can perform. The named
        // action is their road in; everyone else double-taps.
        .accessibilityAction(named: Text("Caps lock"), onCapsLock)
        .frame(
            width: KeyboardMetrics.functionKeyWidth(keyUnit: unit),
            height: keyHeight
        )
    }

    private func backspaceKey(unit: CGFloat) -> some View {
        BackspaceKey(
            width: KeyboardMetrics.functionKeyWidth(keyUnit: unit),
            keyHeight: keyHeight,
            onBackspace: onBackspace
        )
    }
}

/// The comet trail behind a gliding finger. Reduce Motion gets a uniform line —
/// same information, no animated fade.
private struct GlideTrailView: View {
    let points: [CGPoint]
    let reduceMotion: Bool

    var body: some View {
        Canvas { context, _ in
            guard points.count > 1 else { return }
            // `KeyPalette.trail` is tuned for these two opacities over the keycaps, and
            // KeyPaletteContrastTests holds both to the 3:1 non-text floor: the trail
            // is the only feedback that a touch has become a glide.
            if reduceMotion {
                var path = Path()
                path.addLines(points)
                context.stroke(path, with: .color(KeyPalette.trail.opacity(KeyPalette.trailReducedMotionOpacity)),
                               style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            } else {
                // Newest segments brightest: opacity climbs along the trail to the head.
                let count = points.count
                let tail = 0.15
                for index in 1..<count {
                    var segment = Path()
                    segment.move(to: points[index - 1])
                    segment.addLine(to: points[index])
                    let progress = Double(index) / Double(count)
                    let opacity = tail + (KeyPalette.trailHeadOpacity - tail) * progress
                    context.stroke(segment, with: .color(KeyPalette.trail.opacity(opacity)),
                                   style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}
