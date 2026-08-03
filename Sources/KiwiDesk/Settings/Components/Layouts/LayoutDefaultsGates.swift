import KiwiDeskCore
import SwiftUI

/// The Layout Defaults area's greying, resolved from the census
/// (#678 Phase 3, turn 10).
///
/// No container here carries a `SettingsContainer.gate` — a
/// layout's card is never off as a unit, because the card IS the
/// layout the reader picked — so unlike the Bars area this
/// resolver answers only ROW gates. It answers all of them: a
/// declared gate is resolved here and never re-implemented
/// beside its row, because a renderer whose predicate drifts
/// from the declaration greys the wrong row and the census's
/// stated owner quietly stops being the owner.
///
/// The predicates themselves stay wiring-owned, which is the
/// split gui.md draws: the census `gate:` names the *setting*
/// that decides, and the exact question — resolved override
/// chains, auto sentinels — lives here with the values it reads.
/// Three of them ask about per-space overrides as well as the
/// global, and that is not an inconsistency to tidy away: the
/// census names both owners for exactly those three rows (#406 —
/// gate on the RESOLVED value, since a control the global would
/// silence is still live for a space that overrides it), and
/// names one owner only where the override half is **Lua-only**
/// and so cannot be surfaced (grid auto-size, track
/// auto-tracks). A row whose override twin IS in the GUI and is
/// gated on one owner is that bug, not that exception.
///
/// Returning the *reason* rather than a bare Bool is deliberate:
/// why-you-cannot is always inline (item 19), so a row that
/// greys and a row that explains why it greys must not be two
/// decisions that can disagree. The reason is a CASE, and
/// `LayoutDefaultsGateHelp` renders the sentence — the same
/// split Core and the GUI keep (#96), and what lets the whole
/// resolver be asserted off the main actor.
struct LayoutDefaultsGates {
    let settings: TilingSettings

    /// Why a row is inert. Each case is one predicate over the
    /// staged config; the sentence lives with the renderer.
    enum InertReason: Hashable {
        case oneMaster
        case rigidGrid
        case autoSizedGrid
        case autoTracks
        case scrollAnimationOff
    }

    /// Why `key`'s row is inert right now, or nil while it is
    /// live. Fail-OPEN on a gate this type does not own — loud in
    /// debug, live in release — matching `BarsGates` and
    /// `ShortcutsGates`, which is the one policy this
    /// codebase has for the class: a missing case must not lock a
    /// shipped Settings row, and of the two silent readings, a
    /// live row the user can ignore beats a dead one they cannot
    /// explain. `everyGatedRowIsResolved` keeps that arm
    /// unreachable rather than merely believed to be.
    func inertReason(for key: SettingKey) -> InertReason? {
        guard key.placement.gate != nil else { return nil }
        switch key {
        case .layout(.stackMasterOrientation):
            return masterOrientationIsInert ? .oneMaster : nil
        case .layout(.gridFillEmptySpace):
            return fillEmptyIsInert ? .rigidGrid : nil
        case .layout(.gridColumns), .layout(.gridRows):
            return dimensionsAreInert ? .autoSizedGrid : nil
        case .layout(.trackLimit):
            return settings.track.autoTracks ? .autoTracks : nil
        case .colours(.animationsScrollSpeedMS):
            return settings.animations.onScrolling
                ? nil : .scrollAnimationOff
        default:
            assertionFailure(
                "unhandled Layout Defaults gate: \(key.id)"
            )
            return nil
        }
    }

    /// The gated rows this resolver answers. Data, so the guard
    /// asserts the split against the census instead of restating
    /// it — a new gated row in this area lands in neither set and
    /// reds.
    static let resolved: Set<SettingKey> = [
        .layout(.stackMasterOrientation),
        .layout(.gridFillEmptySpace),
        .layout(.gridColumns),
        .layout(.gridRows),
        .layout(.trackLimit),
        .colours(.animationsScrollSpeedMS),
    ]

    /// Gated rows the area declares but resolves elsewhere. Empty
    /// today, and kept as a declared slot rather than dropped:
    /// its absence is what would otherwise make a future
    /// unanswerable gate look like an omission instead of a
    /// decision.
    static let resolvedElsewhere: Set<SettingKey> = []

    // MARK: - The predicates

    /// Whether any overriding space's RESOLVED grid satisfies
    /// `predicate`.
    ///
    /// A control on this GLOBAL editor is inert only when nothing
    /// still reads it — and a per-space override can keep it live
    /// after the global condition would silence it. Asking the
    /// global alone greys a control that is running, the worse of
    /// the two failure directions (#520 wrote the rule one level
    /// down: ask the value that is actually read, never the
    /// global; #527 found this pair still asking the global).
    ///
    /// Resolved through Core's own `resolvedGrid(for:)` rather
    /// than off the raw override fields, because the per-space
    /// surface that draws the same condition and shows the same
    /// sentence resolves it that way — two surfaces answering
    /// "is this space rigid" differently is the drift the
    /// resolver exists to prevent.
    ///
    /// Deliberately ignores whether that space also overrides the
    /// gated value itself. If it does, the control is inert for
    /// it and we leave it enabled anyway — erring toward enabled
    /// is the safe direction here.
    private func anyOverridingSpace(
        _ predicate: (GridParams) -> Bool
    ) -> Bool {
        settings.grid.override.keys.contains {
            predicate(settings.resolvedGrid(for: $0))
        }
    }

    /// Fill-empty applies to dynamic grids only, so a rigid
    /// global silences it — unless a space overrides its type
    /// back to dynamic, which makes the global value live again.
    private var fillEmptyIsInert: Bool {
        settings.grid.type == .rigid
            && !anyOverridingSpace { $0.type == .dynamic }
    }

    /// Auto-size supplies the dimensions, so it silences the
    /// Columns/Rows steppers — unless a space overrides auto-size
    /// OFF, which makes the global dimensions live for it.
    private var dimensionsAreInert: Bool {
        settings.grid.autoSize
            && !anyOverridingSpace { !$0.autoSize }
    }

    /// Orientation only changes anything with more than one
    /// master — and the count that decides is the RESOLVED one,
    /// since a space overriding it to several masters reads this
    /// orientation whatever the global says. The census names
    /// both owners for this row for that reason.
    private var masterOrientationIsInert: Bool {
        settings.stack.masterCount <= 1
            && !settings.stack.override.keys.contains {
                settings.resolvedStack(for: $0).masterCount > 1
            }
    }
}

/// The why-you-cannot sentences for the Layout Defaults rows —
/// one per `LayoutDefaultsGates.InertReason`, so the compiler
/// refuses a reason with nothing to say. Authored beside the
/// predicates that raise them, so a gate and its explanation are
/// edited together.
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
            "Orientation only changes anything with more than "
                + "one master window."
        )
    }

    static var rigidGrid: String {
        L(
            "scroll_grid.fill_empty_space.rigid_only",
            "A rigid grid keeps every cell, so there is no empty "
                + "space to fill."
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
            "The track limit follows the screen while Auto track "
                + "limit is on."
        )
    }

    static var scrollAnimationOff: String {
        L(
            "scroll_grid.scroll_speed.animation_off",
            "Focus shifts jump straight to the slot while "
                + "Animate focus shifts is off."
        )
    }
}
