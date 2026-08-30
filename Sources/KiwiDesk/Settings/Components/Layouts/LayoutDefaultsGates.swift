import KiwiDeskCore
import SwiftUI

/// Resolves inert row gates and reasons for Layout Defaults settings
/// (#678 Phase 3, #406, #96).
struct LayoutDefaultsGates {
    let settings: TilingSettings

    /// Why a setting row is inert.
    enum InertReason: Hashable {
        case oneMaster
        case rigidGrid
        case autoSizedGrid
        case autoTracks
        case scrollAnimationOff
    }

    /// Resolves inert reason for setting key (fail-open if unhandled).
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .layout(.stackMasterOrientation):
            return masterOrientationIsInert ? .oneMaster : nil
        case .layout(.gridFillEmptyCells):
            return fillEmptyIsInert ? .rigidGrid : nil
        case .layout(.gridColumns), .layout(.gridRows):
            return dimensionsAreInert ? .autoSizedGrid : nil
        case .layout(.trackLimit):
            return settings.track.autoTracks ? .autoTracks : nil
        case .colours(.animationsScrollDurationMS):
            return settings.animations.onScrolling
                ? nil : .scrollAnimationOff
        default:
            assertionFailure(
                "unhandled Layout Defaults gate: \(key.id)"
            )
            return nil
        }
    }

    static let resolved: Set<SettingKey> = [
        .layout(.stackMasterOrientation),
        .layout(.gridFillEmptyCells),
        .layout(.gridColumns),
        .layout(.gridRows),
        .layout(.trackLimit),
        .colours(.animationsScrollDurationMS),
    ]

    static let resolvedElsewhere: Set<SettingKey> = []

    /// Checks if any space override satisfies predicate (#520, #527).
    private func anyOverridingSpace(
        _ predicate: (GridParams) -> Bool
    ) -> Bool {
        settings.grid.override.keys.contains {
            predicate(settings.resolvedGrid(for: $0))
        }
    }

    private var fillEmptyIsInert: Bool {
        settings.grid.type == .rigid
            && !anyOverridingSpace { $0.type == .dynamic }
    }

    private var dimensionsAreInert: Bool {
        settings.grid.autoSize
            && !anyOverridingSpace { !$0.autoSize }
    }

    private var masterOrientationIsInert: Bool {
        settings.stack.masterCount <= 1
            && !settings.stack.override.keys.contains {
                settings.resolvedStack(for: $0).masterCount > 1
            }
    }
}

/// User-facing explanations for inert Layout Defaults settings (#96).
@MainActor
enum LayoutDefaultsGateHelp {
    static func sentence(
        for reason: LayoutDefaultsGates.InertReason
    ) -> String {
        switch reason {
        case .oneMaster: return oneMaster
        case .rigidGrid: return rigidGrid
        case .autoSizedGrid: return autoSizedGrid
        case .autoTracks: return autoTracks
        case .scrollAnimationOff: return scrollAnimationOff
        }
    }

    static var oneMaster: String {
        L(
            "layout_params.master_orientation.one_master",
            "%1$@ only changes anything with more than "
                + "one master window.",
            L(
                "layout_params.master_orientation",
                "Master orientation"
            )
        )
    }

    static var rigidGrid: String {
        L(
            "scroll_grid.fill_empty_cells.rigid_only",
            "A rigid grid keeps every cell, so an empty cell "
                + "stays empty rather than being filled."
        )
    }

    static var autoSizedGrid: String {
        L(
            "scroll_grid.auto_size.dimensions_inert",
            "An auto-sized grid takes its columns and rows from "
                + "the screen."
        )
    }

    static var autoTracks: String {
        L(
            "track.auto_tracks.limit_inert",
            "The track limit follows the screen while %1$@ is on.",
            L("track.auto_tracks", "Auto track limit")
        )
    }

    static var scrollAnimationOff: String {
        L(
            "scroll_grid.scroll_duration.animation_off",
            "Focus shifts jump straight to the slot while "
                + "%1$@ is off.",
            L(
                "scroll_grid.animate_focus_shifts",
                "Animate focus shifts"
            )
        )
    }
}
