import UIKit

/// The keyboard's shift state paired with its provenance — the one fact the pure
/// derivation rule cannot recover after the fact: whether the current engagement came
/// from the user's finger or from `Autocapitalization` itself.
///
/// The three transitions mirror what the view can do to shift, so the sequences that
/// were previously only reachable through live UI (delete back into a word, tap shift
/// to cancel an auto-arm, leave an `.allCharacters` field) are plain value sequences
/// here and are pinned by `AutoShiftTests`.
public struct AutoShift {
    public private(set) var state: ShiftState = .off

    /// True when `state`'s engagement was produced by `apply`, not the user. Off states
    /// carry no provenance — except the one below, which is exactly the off that needs it.
    public private(set) var isAutoArmed: Bool = false

    /// Set when a tap turned caps lock OFF. Without it the declination lasts one letter:
    /// an `.allCharacters` field re-derives `.capsLocked` after every insert, so the user
    /// who turned the lock off was silently re-locked mid-word. Per-field state — the view
    /// resets to a fresh `AutoShift()` on every field change — and withdrawn the moment
    /// the user asks for the lock again.
    private var capsDeclined = false

    public init() {}

    /// Re-derives from the field. A manual engaged state passes through untouched (and
    /// without reading the document); an auto-armed one is recomputed from context; a
    /// re-derived caps lock is refused while the user's declination stands.
    public mutating func apply(type: UITextAutocapitalizationType, contextBefore: @autoclosure () -> String?) {
        let wasManual = state != .off && !isAutoArmed
        let next = Autocapitalization.nextShift(
            for: type,
            contextBefore: contextBefore(),
            current: state,
            autoArmed: isAutoArmed
        )
        if next == .capsLocked && !wasManual && capsDeclined {
            // The field would re-arm the lock the user turned off. Their tap wins
            // for as long as they stay in this field.
            state = .off
            isAutoArmed = false
            return
        }
        state = next
        isAutoArmed = !wasManual && state != .off
    }

    /// The shift key: stock's shift is a toggle at any speed. A tap on either engaged
    /// state releases it — the old slow three-tap cycle is gone, because with the double
    /// tap owning caps lock (`setCapsLock`), the cycle's middle step only turned a change
    /// of mind into ALL CAPS. A tap from off arms one manual shift. Turning the lock off
    /// is remembered for the rest of the field (see `capsDeclined`).
    public mutating func userTappedShift() {
        if state == .capsLocked { capsDeclined = true }
        state = state == .off ? .shifted : .off
        isAutoArmed = false
    }

    /// Jump straight to caps lock — stock's double-tap-shift gesture, and the assistive
    /// route's named action.
    ///
    /// Manual by definition, so it clears the auto-armed provenance exactly as a tap
    /// does; otherwise the next context re-derivation could drop the lock the user just
    /// asked for. Asking for the lock also withdraws any earlier declination.
    public mutating func setCapsLock() {
        state = .capsLocked
        isAutoArmed = false
        capsDeclined = false
    }

    /// After a letter lands: a one-shot shift is consumed (and its provenance with it),
    /// caps lock persists with whatever provenance it had.
    public mutating func didInsertLetter() {
        state = state.afterInsert()
        if state == .off {
            isAutoArmed = false
        }
    }
}
