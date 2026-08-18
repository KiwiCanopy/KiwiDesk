import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The caption suite's Monocle half (#881), split from
/// `LayoutSchematicCaptionTests` before that file reached the
/// ceiling — same charter: a preview's words switch with the
/// control that changes them, and a caption may not point at a
/// mark the frame does not draw.
///
/// Locale note as in the parent suite: these assertions read no
/// English and compare rendered strings against rendered
/// strings, so they hold in whatever locale a concurrent suite
/// last selected.
///
/// `@MainActor` because the prose producers are members of a
/// `View`: off the main actor the first read traps in the
/// concurrency runtime rather than failing an expectation.
@Suite("Layout preview captions — Monocle park")
@MainActor
struct LayoutSchematicCaptionMonocleTests {
    /// Park's frame is not Stack's (the fan collapses), and the
    /// instant switch is a motion fact only the words carry —
    /// a shared caption would state the park fact under
    /// `stack`, over a fan the park frame never draws, and
    /// VoiceOver would assert it again.
    @Test("Park says something Stack does not, both orientations")
    func parkReachesTheWords() {
        for orientation in [
            MonocleParams.Orientation.horizontal, .vertical,
        ] {
            let stacked = monocle(
                orientation: orientation,
                hideStyle: .stack
            )
            let parked = monocle(
                orientation: orientation,
                hideStyle: .park
            )
            #expect(stacked.caption != parked.caption)
            #expect(stacked.axLabel != parked.axLabel)
        }
        // The orientation still reaches the words under park:
        // the cycle direction is the axis's fact.
        #expect(
            monocle(orientation: .horizontal, hideStyle: .park)
                .caption
                != monocle(
                    orientation: .vertical,
                    hideStyle: .park
                ).caption
        )
    }

    /// The frame collapses the behind-fan exactly under park —
    /// asserted on the arithmetic (`fanDepth`), the count-guard
    /// rule, not a scan for the input.
    @Test("Park collapses the fan; Stack keeps it")
    func parkCollapsesTheFan() {
        let stacked = monocle(hideStyle: .stack)
        let parked = monocle(hideStyle: .park)
        #expect(stacked.fanDepth == stacked.depth)
        #expect(stacked.fanDepth > 0)
        #expect(parked.fanDepth == 0)
    }

    /// The corner pile is on the frame exactly where the words
    /// may claim it: park, at `.panel`, with members to park. A
    /// thumbnail leaves it undrawn (#753) and a lone window
    /// parks nothing.
    @Test("The pile is drawn at .panel and withheld at .tile")
    func pileMatchesTheScaleRule() {
        #expect(monocle(hideStyle: .park).drawsParkedPile)
        #expect(
            !monocle(hideStyle: .park, scale: .tile)
                .drawsParkedPile
        )
        #expect(!monocle(hideStyle: .stack).drawsParkedPile)
        #expect(
            !monocle(hideStyle: .park, windows: 1)
                .drawsParkedPile
        )
        // The count still answers here: the pile depth is the
        // fan's own count-derived quantity.
        #expect(monocle(hideStyle: .park, windows: 2).depth == 1)
    }

    private func monocle(
        orientation: MonocleParams.Orientation = .horizontal,
        hideStyle: MonocleParams.HideStyle,
        windows: Int = LayoutSchematic.defaultWindowCount,
        scale: SchematicScale = .panel
    ) -> MonocleSchematic {
        MonocleSchematic(
            orientation: orientation,
            hideStyle: hideStyle,
            windows: windows,
            scale: scale
        )
    }
}
