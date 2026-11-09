@testable import KiwiDeskCore

/// The census's register (#930 ruling 5): every id-keyed store a
/// `KiwiCore` holds, with whether an in-place restart carries it.
extension SnapshotStoreCensusTests {
    /// Path → carry and why. A `[]` segment is a dictionary value.
    static let register: [String: (Carry, String)] = [
        "state.windows.windows": (.always, "the window records"),
        "state.workspaces.spaces": (.always, "the Space records"),
        "state.workspaces.spaces[].windows":
            (.always, "membership and order; `SnapshotCarryCensusTests`"),
        "state.workspaces.spaces[].stackWeights":
            (.inPlace, "the session sizing; `SnapshotCarryCensusTests`"),
        "state.workspaces.spaces[].trackBreaks":
            (.always, "the track partition (#128)"),
        "state.workspaces.spaces[].trackWeights":
            (.always, "the track partition (#128)"),
        "state.workspaces.spaces[].handedBreaks":
            (.behind, "a break's provenance; draws nothing (#1387)"),
        "state.workspaces.spaces[].runHeads":
            (.inPlace, "where a scrolled zone rests (#2235)"),
        "state.workspaces.spaces[].runTails":
            (.inPlace, "where a scrolled zone ends (#2235)"),
        "tiler.runCovers":
            (.behind, "what the last pass's runs drew, redrawn (#2235)"),
        "state.userFloated":
            (.stop, "a float set by hand, which the scan cannot see"),
        "state.stickyReachOverrides":
            (.inPlace, "a reach pin set by hand"),
        "state.rememberedSpaces":
            (.always, "carried as each Space's pending filings (#2008)"),
        "tiler.monocleShownMembers":
            (.inPlace, "the member Monocle shows under a float focus"),
        "tiler.stashedFrames":
            (.always, "a parked float's capture rides its record frame"),
        "tiler.stashSent":
            (.behind, "which capture the restore sent (#2129)"),
        "tiler.stashDepartures.shown":
            (.behind, "which Spaces the last park saw shown (#1508)"),
        "tiler.stashDepartures.owed":
            (.behind, "parks a switch still forces (#1508)"),
        "state.floatFrames":
            (
                .behind,
                "where a tiled window returns when floated again "
                    + "(#1675) — no frame at the restart; it is "
                    + "placed anew"
            ),
        "state.tiledOverRule":
            (
                .inPlace,
                "a Tile over a float rule (#2975) — a crash or a "
                    + "quit floats the window by its rule again"
            ),
        "state.maximizedFloatReturn":
            (
                .inPlace,
                "a maximized float's return frame (#3036) — every "
                    + "snapshot records it as the window's frame, so "
                    + "a crash or a quit returns it there"
            ),
        "state.floatAspects":
            (
                .behind,
                "a float's judged aspect lock (#2973) — the "
                    + "first press after a restart judges it again"
            ),
        "tiler.boundLearner.lastAsks":
            (.behind, "the size-bound learner (#677) — a residue"),
        "tiler.boundLearner.candidates":
            (.behind, "the size-bound learner (#677) — a residue"),
        "tiler.boundLearner.bounds":
            (.behind, "the size-bound learner (#677) — a residue"),
        "tiler.boundLearner.tombstones":
            (.behind, "the size-bound learner (#677) — a residue"),
        "tiler.boundLearner.probes":
            (.behind, "the size-bound learner (#1439) — a residue"),
        "state.workspaces.order":
            (.behind, "declared by the config at load"),
        "state.workspaces.referenced":
            (.behind, "derived by the config load"),
        "state.workspaces.spaceDisplay":
            (.behind, "resolved from the screens at load"),
        "state.workspaces.secondaryShown":
            (
                .behind,
                "another screen's shown Space — the replay restores "
                    + "the active one; a residue"
            ),
        "state.heldSpaces":
            (.always, "held Spaces, re-created at boot (#1646)"),
        "state.temporaryArmed":
            (.always, "temporary Spaces, re-created at boot (#1790)"),
        "state.owedShortcutDrops":
            (.behind, "paid at the retile after the drop (#1827)"),
        "spaceHistory.trails.trails[].visits":
            (.behind, "the Space history starts fresh, by ruling (#1655)"),
        "state.profilePartitioning.byArrangement[]":
            (
                .always,
                "an arrangement's Space map, adopted at boot (#1802)"
            ),
        "state.profilePartitioning.byArrangement[][]":
            (
                .always,
                "a Space's windows in that record, adopted at boot (#1802)"
            ),
        "state.restoredFrames":
            (
                .always,
                "rides a window record beside its filing (#2008), "
                    + "with the hand float it is owed (#1864)"
            ),
        "state.departedSlots":
            (.behind, "a Desktop departure's slot (#1207)"),
        "state.unjudgedFilings":
            (.behind, "a boot's unanswered judge; ends the carry (#1646)"),
        "state.focusRecency":
            (.behind, "which window was focused last (#1840); a residue"),
        "state.closedDepartures":
            (.behind, "a close's mark, consumed at the next arrival"),
        "state.awayWindows":
            (.behind, "re-seeded from the compositor at boot (#1146)"),
        "ownFronts":
            (.behind, "an age-bounded intent ledger (#1861)"),
        "desktopMemory.stackFlips[]":
            (
                .behind,
                "a session adjustment keyed by native Desktop ids, "
                    + "which a restart may re-mint (#2771)"
            ),
        "desktopMemory.sessionRatios[][]":
            (.inPlace, "per-Desktop sizes; SessionRatioCarryTests"),
        "drawnSpaceModes":
            (.behind, "settled by the replay itself (#1177)"),
        "arrivals.ledger.created":
            (.behind, "a restart's adoptions are no new windows (#2478)"),
        "arrivals.waiting":
            (.behind, "a stop drops a held arrival's event (#2630)"),
        "arrivals.landed":
            (.behind, "a stop drops a held arrival's event (#2630)"),
        "tiler.placements.entries":
            (.behind, "an age-bounded echo ledger (#1161)"),
        "tiler.motionGate.owedWrites":
            (.behind, "a write owed until the hand rests (#2627)"),
        "tiler.applier.instantTargets.entries":
            (.behind, "an age-bounded echo ledger (#881)"),
        "tiler.applier.instantTargets.owedLapses":
            (.behind, "a lapse owed until its echo or grace (#2882)"),
        "tiler.applier.recent.stamps":
            (.behind, "an age-bounded echo ledger (#1254)"),
        "tiler.animation.animations[]":
            (.behind, "an animation in flight"),
        "tiler.animation.ticks.heldSize":
            (.behind, "an animation in flight (#45)"),
        "state.crossSession.placed":
            (
                .behind,
                "a cross-session match in flight (#1385); an in-place "
                    + "restart carries ids instead"
            ),
        "borders.cornerRadii": (.behind, "render state, redrawn"),
        "borders.overlays": (.behind, "render state, redrawn"),
        "borders.specs": (.behind, "render state, redrawn"),
        "borders.watch.heard[]": (.behind, "render state, re-requested"),
        "stickyMarks.overlays": (.behind, "render state, redrawn"),
    ]
}
