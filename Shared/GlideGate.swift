import CoreGraphics
import Foundation

/// The two gates between a touch on the letters page and the glide decoder.
///
/// Both are pure geometry over the same key centres the page draws with, kept out of
/// the view for the reason every text-entry rule is: the keyboard cannot be driven in
/// the Simulator, so the decisions a finger makes have to be testable as values.
public enum GlideGate {

    /// How far from the nearest letter centre a glide may begin. 0.9 units reaches a
    /// letter key's corners and rejects the function keys: a thumb drifting off a held
    /// backspace or shift is not a word.
    public static let originRadiusFactor: CGFloat = 0.9

    /// Below this much travel, in key units, a trace is a tap. Two adjacent keys sit a
    /// unit and a gap apart centre to centre, so a finger that has moved less than one
    /// key's width never drew a two-letter word — but it did clear the drag threshold,
    /// which used to swallow the tap and hand an 18pt stub to the decoder, where the
    /// lexicon's "ty", "sd" and "nm" were waiting.
    public static let tapArcFactor: CGFloat = 1.0

    /// Whether a glide may begin at `point`.
    public static func beginsOnLetter(
        at point: CGPoint,
        centers: [SleepTokenLetter: CGPoint],
        keyUnit: CGFloat
    ) -> Bool {
        guard let nearest = nearestDistance(to: point, centers: centers) else { return false }
        return nearest <= keyUnit * originRadiusFactor
    }

    /// The letter a tap-like trace should type, or nil when the trace is a real glide.
    ///
    /// Tap-like means the finger travelled less than `tapArcFactor` key units along its
    /// whole path — arc length, not displacement, so a wobble that doubles back is
    /// judged by how far the thumb actually moved. The key under the LIFT is the one
    /// typed: stock lets a finger slide onto the neighbouring key before releasing and
    /// types the key it lifts on, and a roll from a key's edge onto the next key is
    /// that gesture, not a word.
    public static func tapLikeLetter(
        trace: [CGPoint],
        centers: [SleepTokenLetter: CGPoint],
        keyUnit: CGFloat
    ) -> SleepTokenLetter? {
        guard let lift = trace.last else { return nil }
        guard GlideDecoder.length(of: trace) < keyUnit * tapArcFactor else { return nil }
        return nearestLetter(to: lift, centers: centers)
    }

    static func nearestLetter(
        to point: CGPoint,
        centers: [SleepTokenLetter: CGPoint]
    ) -> SleepTokenLetter? {
        centers.min {
            hypot($0.value.x - point.x, $0.value.y - point.y)
                < hypot($1.value.x - point.x, $1.value.y - point.y)
        }?.key
    }

    private static func nearestDistance(
        to point: CGPoint,
        centers: [SleepTokenLetter: CGPoint]
    ) -> CGFloat? {
        centers.values.map { hypot($0.x - point.x, $0.y - point.y) }.min()
    }
}
