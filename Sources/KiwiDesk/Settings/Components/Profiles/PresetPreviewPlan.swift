import KiwiDeskCore
import SwiftUI

/// What the preset preview sheet draws (#859), derived from the
/// LAYOUT's own accessors and nothing else.
///
/// The sheet's whole claim is that it shows what applying the
/// preset produces, so every mode here comes from
/// `StandardLayout.mode(of:on:)` — the same accessor
/// `ProfileComposition.compose` builds a real profile from and
/// the same one `PresetScreenCard` reads for its glyphs. A second
/// derivation beside the drawing is what gui.md's "a preview that
/// claims engine behavior asks the engine" forbids, and the card
/// carried exactly that copy until `StandardLayout+Screens`
/// existed.
///
/// **`liveSizes` threads through unchanged**, for the reason
/// `mode(of:on:)` states in its own docstring: a caller that CAN
/// know the hardware and passes nil makes the preview and the
/// apply disagree. The sheet opens from the "For other setups"
/// drawer too, where there genuinely is no hardware to resolve
/// against — there nil is correct and the historic `bsp` stands,
/// which is also what Apply would lay down on screens the user
/// does not have.
///
/// A value type rather than a view property so the whole
/// derivation is assertable off the main actor
/// (`PresetPreviewPlanTests`).
struct PresetPreviewPlan: Equatable {
    /// One drawn schematic: a planned space and the mode it opens
    /// in.
    struct Slot: Equatable, Identifiable {
        let space: SpaceID
        let mode: LayoutMode
        var id: SpaceID { space }
    }

    /// One screen's spaces, in plan order.
    ///
    /// **A screen the preset plans nothing for is not in this
    /// list.** The sheet's subject is the layouts a preset opens,
    /// and a screen with no spaces opens none — so it would draw
    /// a heading over an empty row. No shipped preset has one and
    /// none may acquire one silently: `PresetPreviewPlanTests`
    /// requires every preset in the catalog to yield exactly one
    /// group per screen, so a future preset leaving a screen empty
    /// reds and the decision gets made then rather than rendering
    /// as a gap.
    struct Group: Equatable, Identifiable {
        let screen: Int
        let slots: [Slot]
        var id: Int { screen }
    }

    let groups: [Group]

    /// Every schematic the sheet draws, flattened — the count the
    /// sheet's own arithmetic is asserted against.
    var slots: [Slot] { groups.flatMap(\.slots) }

    init(layout: StandardLayout, liveSizes: [CGSize]?) {
        // Clamped at zero for the same reason `PresetScreenCard`
        // clamps: a hand-edited layout claiming a negative screen
        // count must not trap on the range.
        let screens = max(layout.screenCount, 0)
        groups = (0..<screens).compactMap { screen in
            let spaces = layout.spaces(
                onScreen: screen,
                screens: screens
            )
            guard !spaces.isEmpty else { return nil }
            let shape = Self.shape(of: screen, in: liveSizes)
            return Group(
                screen: screen,
                slots: spaces.map {
                    Slot(
                        space: $0,
                        mode: layout.mode(of: $0, on: shape)
                    )
                }
            )
        }
    }

    /// The shape of the display this positional screen resolves
    /// to, or nil where the sheet is not drawn against hardware.
    ///
    /// `PresetScreenCard` reads the same thing four lines of its
    /// own, which is a deliberate small duplication (§2.4) rather
    /// than a shared helper: the card's copy is needled by
    /// `ProfilesGateWiringTests` at its own use site, and moving
    /// the expression would repoint that needle for no behavioural
    /// gain. What guards the pair is not the sharing but
    /// `PresetPreviewPlanTests` ▸ the card agreement, which
    /// requires this plan's first mode on every screen of every
    /// shipped preset to equal the card's `openingMode` — so a
    /// drift between the two is loud rather than structural.
    static func shape(
        of screen: Int,
        in liveSizes: [CGSize]?
    ) -> ScreenClass? {
        guard let liveSizes, screen < liveSizes.count else {
            return nil
        }
        return ScreenClass.of(liveSizes[screen])
    }
}
