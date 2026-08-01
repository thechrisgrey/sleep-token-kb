import SwiftUI
import XCTest
@testable import SleepTokenKB

/// WCAG 2.2 AA is a stated, non-negotiable commitment for this app (see PRODUCT.md),
/// but nothing mechanically enforced it — so `inkFaint` shipped at 3.3:1 against its
/// own card surface while carrying the unaffiliated notice and Rune Pad's empty state.
/// These tests pin the floor so the next palette tweak cannot quietly drop below it.
///
/// Every assertion runs against both themes: a role that passes in Ritual can fail in
/// Even in Arcadia, because the two use different ink *and* different stone.
final class ThemeContrastTests: XCTestCase {
    private var originalMode: ThemeMode = .ritual

    override func setUpWithError() throws {
        originalMode = ThemeStore.shared.mode
    }

    override func tearDownWithError() throws {
        ThemeStore.shared.mode = originalMode
    }

    // MARK: - WCAG relative luminance

    /// WCAG 2.x relative luminance. Kept verbatim from the spec rather than
    /// approximated, because the whole point of the test is the exact threshold.
    private func luminance(_ color: Color) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    private func contrast(_ foreground: Color, on background: Color) -> CGFloat {
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func assertContrast(
        _ foreground: Color,
        on background: Color,
        atLeast minimum: CGFloat,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ratio = contrast(foreground, on: background)
        XCTAssertGreaterThanOrEqual(
            ratio, minimum,
            String(format: "%@ is %.2f:1, below the %.1f:1 floor", label, ratio, minimum),
            file: file, line: line
        )
    }

    // MARK: - Body text roles

    /// 4.5:1 is the AA floor for normal-size text. Every role below carries real
    /// prose somewhere in the app, so none of them get the large-text exemption.
    func testBodyInkRolesMeetAAInBothThemes() {
        for mode in ThemeMode.allCases {
            ThemeStore.shared.mode = mode
            let name = mode.rawValue

            for (bg, bgName) in [
                (Theme.field, "field"),
                (Theme.surface, "surface"),
            ] {
                assertContrast(Theme.ink, on: bg, atLeast: 4.5, "\(name): ink on \(bgName)")
                assertContrast(Theme.inkDim, on: bg, atLeast: 4.5, "\(name): inkDim on \(bgName)")
                assertContrast(Theme.inkFaint, on: bg, atLeast: 4.5, "\(name): inkFaint on \(bgName)")
            }

            // Rune Pad's letter-pad hint sits on the raised interactive surface.
            assertContrast(
                Theme.inkFaint, on: Theme.surfaceHigh, atLeast: 4.5,
                "\(name): inkFaint on surfaceHigh"
            )
        }
    }

    /// The accent carries caption-size text (Rune Pad's READS strip), so it is held to
    /// the body floor rather than the 3:1 large-text one.
    func testAccentAndSignalRolesMeetAAInBothThemes() {
        for mode in ThemeMode.allCases {
            ThemeStore.shared.mode = mode
            let name = mode.rawValue

            assertContrast(Theme.gold, on: Theme.surface, atLeast: 4.5, "\(name): gold on surface")
            assertContrast(Theme.gold, on: Theme.field, atLeast: 4.5, "\(name): gold on field")
            assertContrast(
                Theme.sectionInk, on: Theme.field, atLeast: 4.5,
                "\(name): sectionInk on field"
            )
            // Spell-check flags must stay legible in both themes; caution is the one
            // role that deliberately does not retheme.
            assertContrast(
                Theme.caution, on: Theme.surface, atLeast: 4.5,
                "\(name): caution on surface"
            )
        }
    }

    /// The "Open Settings" button paints `field` on a `gold` fill — the one inverted
    /// pairing in the app, and easy to break by darkening the accent.
    func testInvertedButtonFillMeetsAAInBothThemes() {
        for mode in ThemeMode.allCases {
            ThemeStore.shared.mode = mode
            assertContrast(
                Theme.field, on: Theme.gold, atLeast: 4.5,
                "\(mode.rawValue): field on gold"
            )
        }
    }
}
