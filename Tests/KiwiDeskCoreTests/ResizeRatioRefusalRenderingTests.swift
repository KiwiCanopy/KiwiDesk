import Foundation
import Testing

@testable import KiwiDeskCore

/// The two ratio refusals' own derivations (#3643): a limit reached
/// takes its glyph and bump from the press's sign, as `ownMinimum`
/// and `ownMaximum` do, and a ratio that moves the window the other
/// way on a grow bumps nowhere, since no wall was reached.
@Suite("Resize ratio refusal rendering (#3643)")
@MainActor
struct ResizeRatioRefusalRenderingTests {
    private let window = WindowID(1)

    @Test("A ratio limit bumps and draws the press's arrow")
    func limitFollowsThePress() {
        for axis in ["x", "y"] {
            for grows in [true, false] {
                let limit = ResizeRefusal.ratioLimit(
                    window,
                    axis: axis,
                    grows: grows
                )
                let own: ResizeRefusal =
                    grows
                    ? .ownMaximum(window, axis: axis, atBoundary: true)
                    : .ownMinimum(window, axis: axis, appBound: false)
                #expect(limit.bumpDirection == own.bumpDirection)
                #expect(limit.pillSymbol == own.pillSymbol)
                #expect(limit.axis == axis)
                #expect(limit.window == window)
            }
        }
    }

    @Test("A ratio that moves the window the other way never bumps")
    func otherWayHasNoWall() {
        let refusal = ResizeRefusal.ratioMovesOtherWay(window, axis: "x")
        #expect(refusal.bumpDirection == nil)
        #expect(refusal.pillSymbol == "nosign")
        #expect(refusal.window == window)
        #expect(refusal.axis == "x")
    }

    @Test("Each ratio refusal draws its ruled sentence")
    func sentencesAreTheRuling() {
        // English asserted, so the locale is pinned first (#740).
        LocalizationManager.shared.select("en")
        let cases: [(ResizeRefusal, String)] = [
            (
                .ratioLimit(window, axis: "x", grows: true),
                "Largest share reached"
            ),
            (
                .ratioLimit(window, axis: "x", grows: false),
                "Smallest share reached"
            ),
            (
                .ratioMovesOtherWay(window, axis: "x"),
                "This window grows the other way"
            ),
        ]
        for (refusal, text) in cases {
            #expect(refusal.pillText == text)
        }
    }
}
