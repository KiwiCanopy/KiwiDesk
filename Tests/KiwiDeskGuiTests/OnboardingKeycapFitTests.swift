import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The tour's keycap keeps its whole width when its row is tight
/// (#3426): offered less, it does not give the room up by squeezing
/// a "+" between the caps to nothing, so the row's label wraps
/// instead. Main-actor spend: six small renders.
@Suite("Tour keycap keeps its width (#3426)")
@MainActor
struct OnboardingKeycapFitTests {
    /// A wide worded cap, and a gesture's cap (#3427): both carry
    /// "+" separators a tight row could squeeze.
    private var families: [OnboardingKeyFamily] {
        [
            OnboardingKeyFamily(
                id: "worded",
                label: "Switch Spaces",
                chord: .shared(
                    [.control, .option],
                    keys: "3 fingers left/right"
                )
            ),
            OnboardingKeyFamily(
                id: "gesture",
                label: "Switch Spaces",
                chord: .gesture(
                    [.control, .option],
                    glyph: GestureListWords.symbol(.wheelX),
                    caption: "scroll sideways"
                )
            ),
        ]
    }

    /// The keycap's rendered width when offered `width`, or as much
    /// as it asks for when nil.
    private func rendered(
        _ family: OnboardingKeyFamily,
        _ width: CGFloat?
    ) throws -> CGFloat {
        let renderer = ImageRenderer(
            content: OnboardingKeycap(family: family)
                .background(Color.white)
        )
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return try #require(renderer.nsImage).size.width
    }

    @Test("offered less, the keycap keeps its width")
    func keepsItsWidth() throws {
        LocalizationManager.shared.select("en")
        for family in families {
            let ideal = try rendered(family, nil)
            #expect(ideal > 90, "\(family.id) rendered \(ideal) pt")
            for less in [ideal - 8, ideal - 40] {
                #expect(
                    try rendered(family, less) == ideal,
                    "\(family.id), offered \(less) pt, gave up its “+”"
                )
            }
        }
    }
}
