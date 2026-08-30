import KiwiDeskCore
import SwiftUI

/// Derives preset preview structure and layout modes (#859,
/// `PresetPreviewPlanTests`, `SparseModeFallbackTests`).
struct PresetPreviewPlan: Equatable {
    /// One planned space and its layout mode.
    struct Slot: Equatable, Identifiable {
        let space: SpaceID
        let mode: LayoutMode
        var id: SpaceID { space }
    }

    /// One screen's planned spaces.
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

    /// Resolves `ScreenClass` for screen index from live display sizes (#859).
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
