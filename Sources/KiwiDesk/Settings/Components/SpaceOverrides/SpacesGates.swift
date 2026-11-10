import KiwiDeskCore
import SwiftUI

/// Resolves row inertness for per-space layout overrides (#678, #406, #520).
struct SpacesGates {
    let settings: TilingSettings
    let space: SpaceID
    let mode: LayoutMode

    /// Why a row is inert.
    enum InertReason: Hashable, CaseIterable {
        case noOverrides
        case oneMaster
        case rigidGrid
        case autoSizedGrid
        case autoTracks
        case floatingPlacesNone
        case monocleMaximizes
        case monocleAppliesNone
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
        case .gaps(.perSpaceOverride):
            if mode == .floating { return .floatingPlacesNone }
            return settings.maximizesWindows(in: mode)
                ? .monocleMaximizes : nil
        case .behaviour(.minSizePerSpaceOverride):
            return mode == .monocle ? .monocleAppliesNone : nil
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
        .gaps(.perSpaceOverride),
        .behaviour(.minSizePerSpaceOverride),
    ]

    static let resolvedElsewhere: Set<SettingKey> = []
}

extension SpacesGates.InertReason {
    /// The row this reason greys.
    var row: SettingKey {
        switch self {
        case .noOverrides: return .spaces(.spaceOverrideResetActive)
        case .oneMaster: return .layout(.stackOverrideMasterOrientation)
        case .rigidGrid: return .layout(.gridOverrideFillEmptyCells)
        case .autoSizedGrid: return .layout(.gridOverrideColumns)
        case .autoTracks: return .layout(.trackOverrideLimit)
        case .floatingPlacesNone, .monocleMaximizes:
            return .gaps(.perSpaceOverride)
        case .monocleAppliesNone:
            return .behaviour(.minSizePerSpaceOverride)
        }
    }

    /// The census owners whose values cause this reason; empty for
    /// a runtime gate. A row may carry reasons from two
    /// destinations, so the channel is the reason's, not the
    /// row's (#3123).
    var owners: [SettingKey] {
        switch self {
        case .noOverrides: return []
        case .oneMaster:
            return [
                .layout(.stackMasterCount),
                .layout(.stackOverrideMasterCount),
            ]
        case .rigidGrid:
            return [.layout(.gridType), .layout(.gridOverrideType)]
        case .autoSizedGrid: return [.layout(.gridAutoSize)]
        case .autoTracks: return [.layout(.trackAutoTracks)]
        case .floatingPlacesNone, .monocleAppliesNone:
            return [.spaces(.spaceModes)]
        case .monocleMaximizes:
            return [.layout(.monocleMaximizeWindows)]
        }
    }

    /// Whether every owner lives on another destination than the
    /// row, so the reason owes a live link there (#841).
    var isRemote: Bool {
        let area = row.placement.area
        return !owners.isEmpty
            && owners.allSatisfy { $0.placement.area != area }
    }
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
        case .floatingPlacesNone:
            return L(
                "space_override.gaps.floating",
                "Floating places no windows, so these gaps apply when "
                    + "this Space tiles."
            )
        case .monocleMaximizes:
            return L(
                "space_override.gaps.monocle_maximizes",
                "“%1$@” is on for Monocle, so this Space draws no "
                    + "gaps.",
                L("monocle.maximize_windows", "Maximize windows")
            )
        case .monocleAppliesNone:
            return L(
                "space_override.min_size.monocle",
                "Monocle shows one window at a time and applies no "
                    + "minimum, so this size applies when this Space "
                    + "uses another layout."
            )
        }
    }

    /// Remote gate reasons whose switch lives on another
    /// destination (#841, #815), derived from each reason's
    /// owners and bound to the census by `SpacesGateTests`.
    static let remote = Set(
        SpacesGates.InertReason.allCases.filter(\.isRemote)
    )

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
        case .monocleMaximizes:
            return L(
                "space_override.gaps.monocle_maximizes.xref",
                "“%1$@” is on for Monocle, so this Space draws no "
                    + "gaps — change it in %2$@.",
                L("monocle.maximize_windows", "Maximize windows"),
                CrossReferenceRow.linkSlot
            )
        default:
            return nil
        }
    }
}
