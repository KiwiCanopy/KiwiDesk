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
/// apply disagree.
///
/// From the "For other setups" drawer there genuinely is no
/// hardware to resolve against, so nil is correct and the historic
/// `bsp` stands for an unlisted space. **That is NOT what Apply
/// would draw** — `ProfileComposition.compose` clamps those spaces
/// onto the live displays and resolves each mode from the live
/// `ScreenClass`, so the two answers differ for every SPARSE preset
/// — `SparseModeFallbackTests` holds both arms of that fallback,
/// and a count here would rot the day a preset is added or fully
/// declared. What makes the divergence unreachable is that
/// Apply is GATED on the screen-count match
/// (`ProfilesGates`/`.screenCountMismatch`), not that the drawer's
/// answer is right. An earlier draft of this comment claimed the
/// latter (architect review, 2026-08-17); `docs/user-guide.md` ▸
/// Seeing what a preset contains carries the user-facing caveat.
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

    /// One screen's spaces, in plan order — **including a screen
    /// the preset plans nothing for**, which carries an empty
    /// `slots`.
    ///
    /// Empty groups are kept in the value type and dropped at the
    /// DRAWING site (`drawnGroups`), which is what lets
    /// `PresetScreenCard` consume this plan too: the card draws one
    /// outline per screen whether or not that screen has spaces, so
    /// a plan that filtered here could not serve it and the card
    /// kept its own second copy of the same three accessors
    /// (architect + code review, 2026-08-17). The copy is gone; a
    /// filter belongs to whoever is drawing, not to the derivation.
    struct Group: Equatable, Identifiable {
        let screen: Int
        let slots: [Slot]
        var id: Int { screen }

        /// The mode this screen OPENS in — its first space's — or
        /// nil where it plans nothing. What the card's glyph draws.
        var openingMode: LayoutMode? { slots.first?.mode }
    }

    let groups: [Group]

    /// The groups a sheet draws: the ones with something on them.
    ///
    /// A screen with no spaces opens no layouts, so it would be a
    /// heading over an empty row. No shipped preset has one and
    /// none may acquire one silently — `PresetPreviewPlanTests`
    /// requires every preset in the catalog to fill every screen it
    /// plans for, so a future preset leaving one empty reds and the
    /// decision gets made then rather than rendering as a gap.
    var drawnGroups: [Group] { groups.filter { !$0.slots.isEmpty } }

    /// Every schematic the sheet draws, flattened — the count the
    /// sheet's own arithmetic is asserted against.
    var slots: [Slot] { drawnGroups.flatMap(\.slots) }

    /// One screen's group, or nil outside the plan's screens.
    func group(screen: Int) -> Group? {
        groups.first { $0.screen == screen }
    }

    init(layout: StandardLayout, liveSizes: [CGSize]?) {
        // Clamped at zero for the same reason `PresetScreenCard`
        // clamps: a hand-edited layout claiming a negative screen
        // count must not trap on the range.
        let screens = max(layout.screenCount, 0)
        groups = (0..<screens).map { screen in
            let shape = Self.shape(of: screen, in: liveSizes)
            return Group(
                screen: screen,
                slots: layout.spaces(
                    onScreen: screen,
                    screens: screens
                ).map {
                    Slot(
                        space: $0,
                        mode: layout.mode(of: $0, on: shape)
                    )
                }
            )
        }
    }

    /// The shape of the display this positional screen resolves
    /// to, or nil where the plan is not drawn against hardware.
    ///
    /// **The one copy.** `PresetScreenCard` had its own four lines
    /// of this until #859's review round, held to the plan by an
    /// agreement test that could not see the card's half at all —
    /// the card's `shape(of:)` was `private` and the test recomputed
    /// `ScreenClass.of(...)` itself, so a drift in the card's bound
    /// or its index passed green. The docstring here claimed such a
    /// drift would be "loud rather than structural"; it was neither
    /// (code review, 2026-08-17). Both consumers now read this, and
    /// the promise is structural instead of asserted.
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
