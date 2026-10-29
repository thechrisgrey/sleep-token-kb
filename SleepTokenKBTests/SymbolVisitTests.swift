import XCTest
@testable import SleepTokenKB

/// Whether the space bar's return to letters is armed. `PageAfterSpace` only receives a
/// Bool; what sets and clears it used to be a `@State` flag touched from four places in
/// the view with no test. The two stock sequences below are the ones that matter: arming
/// survives the 123 <-> #+= toggle (stock counts the two planes as one visit) and leaving
/// for letters then coming back disarms it.
final class SymbolVisitTests: XCTestCase {

    func testAFreshVisitIsDisarmed() {
        XCTAssertFalse(SymbolVisit().isArmed)
    }

    func testAKeystrokeArmsTheVisit() {
        var visit = SymbolVisit()
        visit.didType()
        XCTAssertTrue(visit.isArmed)
    }

    /// `123 5 #+= space` returns to letters: the digit typed on 123 still arms the space
    /// bar over on #+=.
    func testArmingSurvivesTheSymbolPlaneToggle() {
        var visit = SymbolVisit()
        visit.didType()
        visit.didTogglePlane()
        XCTAssertTrue(visit.isArmed)
        XCTAssertEqual(
            PageAfterSpace.page(from: .symbolsAlt, typedSinceEntering: visit.isArmed, numberPadField: false),
            .letters
        )
    }

    /// `123 5 ABC 123 space` stays on 123: every deliberate page change starts a fresh,
    /// disarmed visit.
    func testLeavingAndComingBackDisarms() {
        var visit = SymbolVisit()
        visit.didType()
        visit.didChangePage()   // ABC
        visit.didChangePage()   // 123 again
        XCTAssertFalse(visit.isArmed)
        XCTAssertEqual(
            PageAfterSpace.page(from: .symbols, typedSinceEntering: visit.isArmed, numberPadField: false),
            .symbols
        )
    }

    /// The space that takes the user back to letters is itself a page change, so the
    /// second space of a double tap arrives disarmed.
    func testThePageChangeAfterASpaceDisarms() {
        var visit = SymbolVisit()
        visit.didType()
        visit.didChangePage()
        XCTAssertFalse(visit.isArmed)
    }

    /// A different host field is a different visit.
    func testAFieldSwitchDisarms() {
        var visit = SymbolVisit()
        visit.didType()
        visit = SymbolVisit()
        XCTAssertFalse(visit.isArmed)
    }
}
