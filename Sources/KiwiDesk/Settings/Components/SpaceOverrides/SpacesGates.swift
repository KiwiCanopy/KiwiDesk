import KiwiDeskCore
import SwiftUI

/// The Spaces & Layouts area's greying, resolved from the census
/// (#678 Phase 3, turn 8). Keyed on a row's own `SettingKey` and
/// returning a REASON case rather than a Bool — the shape General,
/// Layout Defaults and Gaps & Borders already share, so this area
/// adds no new resolver signature.
///
/// Unlike those areas the resolver is PER INSTANCE: every gate
/// here asks about one space (its resolved layout params, its
/// override count), so the context carries the space and its
/// active layout alongside the settings. It answers only ROW
/// gates — no container in this area carries a
/// `SettingsContainer.gate` — and it takes no `SettingsMode`
/// input: the mode never changes what runs (8c), it only decides
/// what is offered, so an override that exists greys the same way
/// in Simple and Power User.
///
/// The five override-row predicates ask the RESOLVED value for the
/// space (#406/#520): a control the global would silence is still
/// live for a space that overrides it, so the per-space editor
/// reads `resolvedStack(for:)`/`resolvedGrid(for:)`/
/// `resolvedTrack(for:)`, the same values the Layout Defaults twin
/// resolves — two surfaces answering "is this Space rigid"
/// differently is the drift the resolver exists to prevent.
///
/// Returning the reason rather than a Bool keeps the grey and its
/// inline sentence from being two decisions that can disagree
/// (`SpacesGateHelp` renders it), and keeps the whole resolver
/// assertable off the main actor.
struct SpacesGates {
    let settings: TilingSettings
    let space: SpaceID
    /// The space's active layout — the one the reset action
    /// counts overrides for. The five layout-override predicates
    /// read the space's resolved params directly and do not
    /// consult it.
    let mode: LayoutMode

    /// Why a row is inert. One case per predicate; the sentence
    /// lives in `SpacesGateHelp`.
    enum InertReason: Hashable {
        case noOverrides
        case oneMaster
        case rigidGrid
        case autoSizedGrid
        case autoTracks
    }

    /// Why `key`'s row is inert for this space right now, or nil
    /// while it is live. Fail-OPEN on a gate this type does not own
    /// — loud in debug, live in release — matching the other area
    /// resolvers: a missing case must not lock a shipped Settings
    /// row, and of the two silent readings a live row the user can
    /// ignore beats a dead one they cannot explain.
    /// `everyGatedRowIsResolved` keeps that arm unreachable rather
    /// than merely believed to be.
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

    /// The gated rows this resolver answers. Data, so
    /// `everyGatedRowIsResolved` reds when a new census gate in
    /// this area lands in neither set instead of hitting the
    /// fail-open default at run time.
    static let resolved: Set<SettingKey> = [
        .spaces(.spaceOverrideResetActive),
        .layout(.stackOverrideMasterOrientation),
        .layout(.gridOverrideFillEmptyCells),
        .layout(.gridOverrideColumns),
        .layout(.gridOverrideRows),
        .layout(.trackOverrideLimit),
    ]

    /// Declared-but-answered-elsewhere. Empty and kept so a new
    /// gate this resolver cannot answer must land here on purpose
    /// rather than pass silently.
    static let resolvedElsewhere: Set<SettingKey> = []
}

/// The inline sentence each `SpacesGates.InertReason` renders —
/// the "why you can't edit this" a greyed row shows on hover.
/// Split from the resolver so the resolver stays assertable off
/// the main actor; the reason and its sentence are one decision,
/// never two that can disagree (#678, gui.md).
///
/// The keys began as verbatim reuses of the hand-wired gates this
/// conversion replaced, which is why the conversion itself
/// dropped no translation.
///
/// **That is history, not a standing property — editing an
/// English sentence here runs `scripts/drop-key` in the same
/// change set.** It shipped as a claim ("the English is unchanged
/// and no translation is dropped"), and two sentences below were
/// then reworded to remove a scope claim while the comment went
/// on asserting the opposite — so ten catalogs kept saying "for
/// this Space" about rows that no longer say it (localization
/// audit, 2026-08-16). A state claim about a file is true only on
/// the day it is written; this one had a reader, and the reader
/// was the author of the very edit that falsified it.
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

    /// The REMOTE reasons — the ones whose switch lives on
    /// another destination (#841).
    ///
    /// `GateReasonPlacement` classifies these three rows
    /// `.remote`: their gating field has no row in the per-space
    /// editor, so unlike every inline grey here the reader
    /// cannot look up and find the switch. Both `.help()` and a
    /// dim are then dead ends — a keyboard or VoiceOver user got
    /// "dimmed" and nothing else, which is #815's complaint in
    /// the one class #815 did not close.
    ///
    /// Data rather than a condition at the call site, so the
    /// classification and the anchor cannot disagree.
    ///
    /// Stated residue, because the honest version is not yet
    /// available: `GateReasonPlacement.channel` already DERIVES
    /// `.remote` from the census, and this set is a second,
    /// hand-kept copy of that answer keyed on the reason rather
    /// than on the `SettingKey` (architect review, 2026-08-16).
    /// They are bound only by `remoteMatchesTheCensus` in
    /// `GateReasonPlacementTests`, which reds if a key's channel
    /// and this set ever disagree — a guard rather than a
    /// derivation, and the derivation is owed.
    static let remote: Set<SpacesGates.InertReason> = [
        .autoSizedGrid, .autoTracks,
    ]

    /// The sentence a `CrossReferenceRow` renders for a remote
    /// reason, carrying the link slot where the destination's
    /// name belongs.
    ///
    /// It names WHERE TO GO, which is the whole of the remote
    /// rule — a sentence that only restates the state leaves the
    /// reader knowing why and not knowing where. And it is a
    /// live link rather than `Text`, or the pointer is dead
    /// (`docs/ui-patterns.md`).
    ///
    /// The gating control's name is **interpolated from its own
    /// key**, never re-typed (#818). This is the sharpest case
    /// for that rule: a cross-reference whose only job is to send
    /// the reader to a row points at nothing once the quoted name
    /// drifts from it — and the sibling `.gates` sentences these
    /// were derived from had already drifted in two catalogs
    /// (`de`'s row reads "Raster automatisch dimensionieren"
    /// against a sentence saying "Automatisches Raster";
    /// `ru`'s row and its sentence likewise). Each specifier is
    /// spent once, so a translation may pronominalise neither
    /// into the other.
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
