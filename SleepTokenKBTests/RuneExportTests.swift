import XCTest
import SwiftUI
import UIKit
@testable import SleepTokenKB

/// `RuneExportStyle` owns every per-style fact so that adding a style is one enum case
/// rather than a hunt across the view. That only holds if each case actually carries a
/// complete, distinct set of facts — which is what these pin.
final class RuneExportTests: XCTestCase {

    private func components(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    /// Rec. 709 luma, enough to tell "light ink" from "dark ink" without asserting exact
    /// design values that are allowed to be retuned.
    private func luminance(_ color: Color) -> CGFloat {
        let c = components(color)
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
    }

    func testEveryStyleCarriesCompleteMenuMetadata() {
        for style in RuneExportStyle.allCases {
            XCTAssertFalse(style.menuTitle.isEmpty, "\(style) has no menu title")
            XCTAssertFalse(style.systemImage.isEmpty, "\(style) has no SF Symbol")
            XCTAssertFalse(style.copiedMessage.isEmpty, "\(style) has no confirmation copy")
        }
    }

    /// All three appear in the same menu at once, so any collision is a genuine ambiguity
    /// for the user rather than a cosmetic duplicate.
    func testMenuEntriesAreDistinct() {
        let titles = RuneExportStyle.allCases.map(\.menuTitle)
        XCTAssertEqual(Set(titles).count, titles.count, "two export styles share a menu title")

        let symbols = RuneExportStyle.allCases.map(\.systemImage)
        XCTAssertEqual(Set(symbols).count, symbols.count, "two export styles share an icon")

        let messages = RuneExportStyle.allCases.map(\.copiedMessage)
        XCTAssertEqual(Set(messages).count, messages.count, "two export styles share a confirmation")
    }

    func testTheSystemImagesAreRealSFSymbols() {
        for style in RuneExportStyle.allCases {
            XCTAssertNotNil(
                UIImage(systemName: style.systemImage),
                "\(style.systemImage) is not an SF Symbol, so the menu row would render blank"
            )
        }
    }

    /// The two transparent styles exist precisely to be pasted onto opposite backgrounds.
    /// If their inks ever converge, one of them is silently useless.
    func testLightAndDarkInkSitOnOppositeSidesOfMidGrey() {
        XCTAssertGreaterThan(luminance(RuneExportStyle.lightInk.ink), 0.5, "light ink is not light")
        XCTAssertLessThan(luminance(RuneExportStyle.darkInk.ink), 0.5, "dark ink is not dark")
    }

    /// The plaque style brings its own background, so it is the one style whose ink and
    /// fill must be checked against each other rather than against the paste target.
    func testPlaqueInkIsLegibleAgainstItsOwnFill() {
        let inkLuma = luminance(RuneExportStyle.plaque.ink)
        let fillLuma = luminance(RuneExportStyle.plaqueFill)
        XCTAssertGreaterThan(
            abs(inkLuma - fillLuma), 0.25,
            "plaque ink and plaque fill are too close to read"
        )
    }

    func testEveryStyleInkIsFullyOpaque() {
        for style in RuneExportStyle.allCases {
            XCTAssertEqual(
                components(style.ink).a, 1, accuracy: 0.001,
                "\(style) ink is translucent, which would double-expose against the export background"
            )
        }
    }

    /// Guards the switch statements: a fourth case added without extending them would trip
    /// this before it ever reached the menu.
    func testTheStyleSetIsTheExpectedThree() {
        XCTAssertEqual(RuneExportStyle.allCases.count, 3)
    }
}
