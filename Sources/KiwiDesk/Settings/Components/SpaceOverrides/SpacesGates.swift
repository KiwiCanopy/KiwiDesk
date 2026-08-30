import KiwiDeskCore
import SwiftUI

/// Resolves row inertness for per-space layout overrides (#678, #406, #520).
struct SpacesGates {
    let settings: TilingSettings
    let space: SpaceID
    let mode: LayoutMode

    /// Why a row is inert.
    enum InertReason: Hashable {
        case noOverrides
        case oneMaster
        case rigidGrid
        case autoSizedGrid
        case autoTracks
    }

    /// Evaluates inert reason for given setting key on this space.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .spaces(.spaceOverrideResetActive):
            return settings.overrideFieldCount(mode, for: space) == 0
                ? .noOverrides : nil
        case .layout(.stackOverrideMasterOrientation):
            return settings.resolvedStack(for: space).masterCount <= 1
                ? .oneMaster : nil
        case .layout(.gridOverrideFillEmptyCells):
            return settings.resolvedGrid(for: space).type == .rigid
                ? .rigidGrid : nil
        case .layout(.gridOverrideColumns),
            .layout(.gridOverrideRows):
            return settings.resolvedGrid(for: space).autoSize
                ? .autoSizedGrid : nil
        case .layout(.trackOverrideLimit):
            return settings.resolvedTrack(for: space).autoTracks
                ? .autoTracks : nil
        default:
            assertionFailure(
                "unhandled Spaces & Layouts gate: \(key.id)"
            )
            return nil
        }
    }

    static let resolved: Set<SettingKey> = [
        .spaces(.spaceOverrideResetActive),
        .layout(.stackOverrideMasterOrientation),
        .layout(.gridOverrideFillEmptyCells),
        .layout(.gridOverrideColumns),
        .layout(.gridOverrideRows),
        .layout(.trackOverrideLimit),
    ]

    static let resolvedElsewhere: Set<SettingKey> = []
}

/// Localized hover and cross-reference text for gated space settings (#678,
/// #841).
@MainActor
enum SpacesGateHelp {
    static func sentence(
        for reason: SpacesGates.InertReason
    ) -> String {
        switch reason {
        case .noOverrides:
            return L(
                "space_override.reset_active.none",
                "There are no overrides to reset."
            )
        case .oneMaster:
            return L(
                "layout_params.master_orientation.one_master",
                "%1$@ only changes anything with more than "
                    + "one master window.",
                L(
                    "layout_params.master_orientation",
                    "Master orientation"
                )
            )
        case .rigidGrid:
            return L(
                "scroll_grid.fill_empty_cells.rigid_only",
                "A rigid grid keeps every cell, so an empty cell "
                    + "stays empty rather than being filled."
            )
        case .autoSizedGrid:
            return L(
                "scroll_grid.auto_size.gates",
                "%1$@ is on, so the screen decides the columns "
                    + "and rows.",
                L("scroll_grid.auto_size", "Auto-size grid")
            )
        case .autoTracks:
            return L(
                "track.auto_tracks.gates",
                "%1$@ is on, so the screen decides how many "
                    + "tracks open.",
                L("track.auto_tracks", "Auto track limit")
            )
        }
    }

    /// Remote gate reasons whose switch lives on another
    /// destination (#841, #815). A hand-kept copy of what
    /// `GateReasonPlacement.channel` derives, bound by
    /// `remoteMatchesTheCensus` (`GateReasonPlacementTests`); the
    /// derivation is owed (architect review, 2026-08-16).
    static let remote: Set<SpacesGates.InertReason> = [
        .autoSizedGrid, .autoTracks,
    ]

    /// Cross-reference navigation sentence for remote gate reasons (#818,
    /// #841).
    static func crossReference(
        for reason: SpacesGates.InertReason
    ) -> String? {
        switch reason {
        case .autoSizedGrid:
            return L(
                "scroll_grid.auto_size.xref",
                "%1$@ is on, so the screen decides the columns "
                    + "and rows — change it in %2$@.",
                L("scroll_grid.auto_size", "Auto-size grid"),
                CrossReferenceRow.linkSlot
            )
        case .autoTracks:
            return L(
                "track.auto_tracks.xref",
                "%1$@ is on, so the screen decides how many "
                    + "tracks open — change it in %2$@.",
                L("track.auto_tracks", "Auto track limit"),
                CrossReferenceRow.linkSlot
            )
        default:
            return nil
        }
    }
}
