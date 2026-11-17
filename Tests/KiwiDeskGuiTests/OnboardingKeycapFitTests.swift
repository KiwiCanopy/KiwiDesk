import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The tour's keycap keeps its whole width when its row is tight
/// (#3426): offered less, it does not give the room up by squeezing
/// a "+" between the caps to nothing, so the row's label wraps
/// instead. Main-actor spend: three small renders.
@Suite("Tour keycap keeps its width (#3426)")
@MainActor
struct OnboardingKeycapFitTests {
    /// The Switch Spaces gesture row: the widest cap in the tour.
    private var family: OnboardingKeyFamily {
        OnboardingKeyFamily(
            id: "switch",
            label: "Switch Spaces",
            chord: .shared([.control, .option], keys: "3 fingers left/right")
        )
    }

    /// The keycap's rendered width when offered `width`, or as much
    /// as it asks for when nil.
    private func rendered(_ width: CGFloat?) throws -> CGFloat {
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
        let ideal = try rendered(nil)
        #expect(ideal > 100, "the keycap rendered \(ideal) pt")
        for less in [ideal - 8, ideal - 40] {
            #expect(
                try rendered(less) == ideal,
                "offered \(less) pt, the keycap gave up its “+”"
            )
        }
    }
}
