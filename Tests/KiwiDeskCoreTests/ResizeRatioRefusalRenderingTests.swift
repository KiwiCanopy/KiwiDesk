import Foundation
import Testing

@testable import KiwiDeskCore

/// The ratio limit's own derivations (#3643): a limit reached takes
/// its glyph and bump from the press's sign, as `ownMinimum` and
/// `ownMaximum` do.
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
        ]
        for (refusal, text) in cases {
            #expect(refusal.pillText == text)
        }
    }
}
