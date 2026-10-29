import SwiftUI
import UIKit
import XCTest
@testable import SleepTokenKB

/// WCAG 2.2 AA for the keyboard extension's own palette, by the same luminance
/// arithmetic `ThemeContrastTests` applies to the host app. The extension is a guest
/// inside other apps and mirrors the system keyboard, so it carries no theme — but it
/// carries text (the Rune·A hint, the chrome captions, the return key's action title)
/// and state feedback (the glide trail), and none of that was ever measured. The hint
/// shipped at ~3.4:1 and the trail at ~1.5:1 in dark mode.
///
/// `KeyPalette` is compiled into this target directly (see project.yml) because the
/// extension module cannot be imported by the tests.
final class KeyPaletteContrastTests: XCTestCase {

    private struct Appearance {
        let name: String
        let traits: UITraitCollection
    }

    /// Both appearances, with and without Increase Contrast.
    private let appearances: [Appearance] = [
        UIUserInterfaceStyle.light, .dark
    ].flatMap { style in
        [UIAccessibilityContrast.normal, .high].map { contrast in
            Appearance(
                name: "\(style == .dark ? "dark" : "light")/\(contrast == .high ? "high" : "normal")",
                traits: UITraitCollection(traitsFrom: [
                    UITraitCollection(userInterfaceStyle: style),
                    UITraitCollection(accessibilityContrast: contrast)
                ])
            )
        }
    }

    // MARK: - WCAG relative luminance

    private func channels(_ color: UIColor, in appearance: Appearance) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: appearance.traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private func luminance(_ rgb: (r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)
    }

    private func contrast(
        _ foreground: UIColor,
        opacity: CGFloat = 1,
        on background: UIColor,
        in appearance: Appearance
    ) -> CGFloat {
        let fg = channels(foreground, in: appearance)
        let bg = channels(background, in: appearance)
        // A translucent stroke is seen composited over its background.
        let mixed = (
            r: opacity * fg.r + (1 - opacity) * bg.r,
            g: opacity * fg.g + (1 - opacity) * bg.g,
            b: opacity * fg.b + (1 - opacity) * bg.b
        )
        let a = luminance(mixed), b = luminance(bg)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func assertContrast(
        _ foreground: UIColor,
        opacity: CGFloat = 1,
        on background: UIColor,
        atLeast minimum: CGFloat,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for appearance in appearances {
            let ratio = contrast(foreground, opacity: opacity, on: background, in: appearance)
            XCTAssertGreaterThanOrEqual(
                ratio, minimum,
                String(format: "%@: %@ is %.2f:1, below the %.1f:1 floor", appearance.name, label, ratio, minimum),
                file: file, line: line
            )
        }
    }

    // MARK: - Text on keycaps

    /// The Rune·A hint is 9pt semibold text on the learning face — the face whose whole
    /// job is the Latin mapping — so it is held to the body floor.
    func testTheLatinHintMeetsAAOnTheKeycap() {
        assertContrast(KeyPalette.hintColor, on: KeyPalette.keycapColor, atLeast: 4.5, "hint on keycap")
    }

    /// Primary label text sits on every fill: letters on keycaps, "123" and "space" on
    /// function keys, the panel's selected option on the active fill.
    func testThePrimaryLabelMeetsAAOnEveryFill() {
        for (fill, name) in [
            (KeyPalette.keycapColor, "keycap"),
            (KeyPalette.functionColor, "function"),
            (KeyPalette.activeColor, "active"),
        ] {
            assertContrast(.label, on: fill, atLeast: 4.5, "label on \(name)")
        }
    }

    /// The return key's action variant paints a white title on a tinted fill; system
    /// blue under white 13pt text is ~4.0:1, so the fill has to be darker than stock's.
    func testTheActionTitleMeetsAAOnTheActionFill() {
        assertContrast(KeyPalette.actionTitleColor, on: KeyPalette.actionColor, atLeast: 4.5, "title on action")
    }

    // MARK: - State feedback

    /// The trail is the only feedback that a touch has become a glide: state feedback
    /// under the 3:1 non-text floor, at the two opacities the view actually strokes —
    /// the Reduce Motion line and the comet's newest segment.
    func testTheGlideTrailMeetsTheNonTextFloorAtItsOpacities() {
        for opacity in [KeyPalette.trailReducedMotionOpacity, KeyPalette.trailHeadOpacity] {
            assertContrast(
                KeyPalette.trailColor, opacity: opacity, on: KeyPalette.keycapColor, atLeast: 3,
                String(format: "trail at %.2f on keycap", opacity)
            )
        }
    }

    // MARK: - Increase Contrast

    private func normal(_ style: UIUserInterfaceStyle) -> Appearance {
        appearances.first { $0.name == "\(style == .dark ? "dark" : "light")/normal" }!
    }

    private func high(_ style: UIUserInterfaceStyle) -> Appearance {
        appearances.first { $0.name == "\(style == .dark ? "dark" : "light")/high" }!
    }

    /// The header claims the palette picks up Increase Contrast; now it does. Every ink
    /// and tint role resolves to a different colour under the trait, in both appearances.
    func testIncreaseContrastChangesTheInkAndTintRoles() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (color, name) in [
                (KeyPalette.hintColor, "hint"),
                (KeyPalette.trailColor, "trail"),
                (KeyPalette.actionColor, "action"),
                (KeyPalette.functionColor, "function"),
            ] {
                XCTAssertNotEqual(
                    color.resolvedColor(with: normal(style).traits),
                    color.resolvedColor(with: high(style).traits),
                    "\(name) ignores Increase Contrast in \(style == .dark ? "dark" : "light")"
                )
            }
        }
    }

    /// Under Increase Contrast the engaged shift fill pulls further from a resting
    /// function key, never closer: the separation is what the setting is for.
    func testIncreaseContrastWidensTheActiveAgainstFunctionGap() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let normalGap = abs(
                luminance(channels(KeyPalette.activeColor, in: normal(style)))
                    - luminance(channels(KeyPalette.functionColor, in: normal(style)))
            )
            let highGap = abs(
                luminance(channels(KeyPalette.activeColor, in: high(style)))
                    - luminance(channels(KeyPalette.functionColor, in: high(style)))
            )
            XCTAssertGreaterThanOrEqual(highGap, normalGap, "Increase Contrast narrowed the active/function gap in \(style.rawValue)")
        }
    }

    /// The hierarchy the palette exists to keep: primary keys are the lightest surface
    /// in every appearance, over the field and over the function keys.
    func testKeycapsStayTheLightestSurfaceInEveryAppearance() {
        for appearance in appearances {
            let keycap = luminance(channels(KeyPalette.keycapColor, in: appearance))
            XCTAssertGreaterThan(keycap, luminance(channels(KeyPalette.functionColor, in: appearance)), appearance.name)
            XCTAssertGreaterThan(keycap, luminance(channels(KeyPalette.fieldColor, in: appearance)), appearance.name)
        }
    }
}
