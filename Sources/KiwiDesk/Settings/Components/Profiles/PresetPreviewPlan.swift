import KiwiDeskCore
import SwiftUI

/// Derives the preset preview from the LAYOUT's own accessors
/// and nothing else (#859, `PresetPreviewPlanTests`).
/// `liveSizes` threads through unchanged — a caller that CAN know
/// the hardware and passes nil makes preview and apply disagree.
/// From the "For other setups" drawer nil is correct, and the
/// drawer's answer genuinely differs from what Apply would draw
/// (`SparseModeFallbackTests`); what makes that unreachable is
/// Apply being GATED on the screen-count match, not the drawer
/// being right (architect review, 2026-08-17).
struct PresetPreviewPlan: Equatable {
    /// One planned space and its layout mode.
    struct Slot: Equatable, Identifiable {
        let space: SpaceID
        let mode: LayoutMode
        var id: SpaceID { space }
    }

    /// One screen's planned spaces — INCLUDING a screen the
    /// preset plans nothing for (empty `slots`): empties are kept
    /// in the value and dropped at the DRAWING site, which is what
    /// lets `PresetScreenCard` consume this plan too (review,
    /// 2026-08-17).
    struct Group: Equatable, Identifiable {
        let screen: Int
        let slots: [Slot]
        var id: Int { screen }

        /// Opening layout mode for the first space on this screen.
        var openingMode: LayoutMode? { slots.first?.mode }
    }

    let groups: [Group]

    /// Non-empty screen groups rendered by preview sheet.
    var drawnGroups: [Group] { groups.filter { !$0.slots.isEmpty } }

    /// All planned slots across drawn groups.
    var slots: [Slot] { drawnGroups.flatMap(\.slots) }

    /// Returns group for specified screen index.
    func group(screen: Int) -> Group? {
        groups.first { $0.screen == screen }
    }

    init(layout: StandardLayout, liveSizes: [CGSize]?) {
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

    /// Resolves `ScreenClass` for a screen index — THE ONE COPY
    /// (#859): `PresetScreenCard` kept its own four lines of this,
    /// held by an agreement test that could not see the card's
    /// private half, so a drift passed green (code review,
    /// 2026-08-17). Both consumers now read this.
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
