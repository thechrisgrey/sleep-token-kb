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
    /// carry no provenance.
    public private(set) var isAutoArmed: Bool = false

    public init() {}

    /// Re-derives from the field. A manual engaged state passes through untouched (and
    /// without reading the document); an auto-armed one is recomputed from context.
    public mutating func apply(type: UITextAutocapitalizationType, contextBefore: @autoclosure () -> String?) {
        let wasManual = state != .off && !isAutoArmed
        state = Autocapitalization.nextShift(
            for: type,
            contextBefore: contextBefore(),
            current: state,
            autoArmed: isAutoArmed
        )
        isAutoArmed = !wasManual && state != .off
    }

    /// The shift key. One tap on an auto-armed shift cancels it — the system keyboard's
    /// behaviour, and the move every lowercase typist expects — rather than advancing
    /// the cycle to caps lock. Any tap makes the resulting state manual.
    public mutating func userTappedShift() {
        if isAutoArmed && state == .shifted {
            state = .off
        } else {
            state = state.toggled()
        }
        isAutoArmed = false
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
