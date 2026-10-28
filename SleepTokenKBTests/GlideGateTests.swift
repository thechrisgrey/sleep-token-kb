import XCTest
@testable import SleepTokenKB

/// The two gates between a touch and the decoder. A glide must begin on a letter, and a
/// thumb that rolls less than a key's width never meant a word: before this gate, a
/// 17.9pt drift from `t` cleared the drag threshold, lost its tap, and decoded as "ty".
final class GlideGateTests: XCTestCase {

    private let width: CGFloat = 393
    private var centers: [SleepTokenLetter: CGPoint]!
    private var unit: CGFloat!

    override func setUp() {
        super.setUp()
        centers = KeyCenters.qwerty(availableWidth: width, keyHeight: KeyboardMetrics.baseKeyHeight)
        unit = KeyboardMetrics.keyUnit(availableWidth: width)
    }

    // MARK: - Tap-like traces

    /// The five stubs the ledger replayed through the decoder: each committed a
    /// two-letter non-word. A roll just past the drag threshold types the key.
    func testAShortRollInsideAKeyIsATapOnThatKey() {
        for letter in [SleepTokenLetter.t, .s, .n, .e, .o] {
            let start = centers[letter]!
            let trace = [start, CGPoint(x: start.x + 9, y: start.y), CGPoint(x: start.x + 17.9, y: start.y)]
            XCTAssertEqual(
                GlideGate.tapLikeLetter(trace: trace, centers: centers, keyUnit: unit), letter,
                "a 17.9pt roll from \(letter.latin) must type \(letter.latin)"
            )
        }
    }

    /// Stock lets a finger slide to the neighbouring key before lifting and types the key
    /// it lifts on. A roll that starts at a key's edge and ends over the next key is
    /// still shorter than a key, so it is a tap — on the key under the lift.
    func testAShortRollOntoTheNeighbourTypesTheKeyUnderTheLift() {
        let t = centers[.t]!
        let edge = CGPoint(x: t.x + unit * 0.45, y: t.y)
        let trace = [edge, CGPoint(x: edge.x + unit * 0.6, y: edge.y)]
        XCTAssertEqual(GlideGate.tapLikeLetter(trace: trace, centers: centers, keyUnit: unit), .y)
    }

    /// A drag of a key and a half is a glide, however short the word.
    func testADragOfMoreThanAKeyIsAGlide() {
        let t = centers[.t]!
        let trace = [t, CGPoint(x: t.x + unit * 1.5, y: t.y)]
        XCTAssertNil(GlideGate.tapLikeLetter(trace: trace, centers: centers, keyUnit: unit))
    }

    /// The decision is about distance travelled, not displacement: a wobble that doubles
    /// back inside one key has still only moved a thumb's worth.
    func testArcLengthNotDisplacementDecides() {
        let t = centers[.t]!
        let backAndForth = [t, CGPoint(x: t.x + unit * 0.6, y: t.y), CGPoint(x: t.x + unit * 0.1, y: t.y)]
        XCTAssertNil(
            GlideGate.tapLikeLetter(trace: backAndForth, centers: centers, keyUnit: unit),
            "1.1 units of travel is past the floor even though the lift is 0.1 units from the start"
        )
        let shortWobble = [t, CGPoint(x: t.x + unit * 0.4, y: t.y), CGPoint(x: t.x + unit * 0.1, y: t.y)]
        XCTAssertEqual(GlideGate.tapLikeLetter(trace: shortWobble, centers: centers, keyUnit: unit), .t)
    }

    func testTheFloorIsExactlyOneKeyUnit() {
        let t = centers[.t]!
        XCTAssertNotNil(GlideGate.tapLikeLetter(
            trace: [t, CGPoint(x: t.x + unit * 0.999, y: t.y)], centers: centers, keyUnit: unit
        ))
        XCTAssertNil(GlideGate.tapLikeLetter(
            trace: [t, CGPoint(x: t.x + unit, y: t.y)], centers: centers, keyUnit: unit
        ))
    }

    func testDegenerateTracesAreNeverGlides() {
        XCTAssertNil(GlideGate.tapLikeLetter(trace: [], centers: centers, keyUnit: unit))
        XCTAssertEqual(GlideGate.tapLikeLetter(trace: [centers[.q]!], centers: centers, keyUnit: unit), .q)
    }

    // MARK: - Where a glide may begin

    /// 0.9 units reaches a letter key's corners; the function keys sit further out.
    func testAGlideMayBeginAnywhereOnALetterKey() {
        for letter in SleepTokenLetter.allCases {
            let center = centers[letter]!
            XCTAssertTrue(GlideGate.beginsOnLetter(at: center, centers: centers, keyUnit: unit))
            let corner = CGPoint(x: center.x + unit * 0.45, y: center.y + KeyboardMetrics.baseKeyHeight * 0.45)
            XCTAssertTrue(
                GlideGate.beginsOnLetter(at: corner, centers: centers, keyUnit: unit),
                "the corner of \(letter.latin) is still on the key"
            )
        }
    }

    /// A thumb drifting off shift or backspace is not the start of a word.
    func testAGlideMayNotBeginOnTheFunctionKeys() {
        let z = centers[.z]!
        let shift = CGPoint(x: z.x - KeyboardMetrics.functionKeyFlank(keyUnit: unit) - unit * 0.6, y: z.y)
        XCTAssertFalse(GlideGate.beginsOnLetter(at: shift, centers: centers, keyUnit: unit))
        let m = centers[.m]!
        let backspace = CGPoint(x: m.x + KeyboardMetrics.functionKeyFlank(keyUnit: unit) + unit * 0.6, y: m.y)
        XCTAssertFalse(GlideGate.beginsOnLetter(at: backspace, centers: centers, keyUnit: unit))
    }
}
