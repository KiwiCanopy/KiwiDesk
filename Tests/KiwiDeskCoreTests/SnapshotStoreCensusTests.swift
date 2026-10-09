import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private typealias F = BootRestoreFixture

/// Every WindowID- or SpaceID-keyed store reachable from a
/// `KiwiCore` — `StateCoordinator`'s, `TilingEngine`'s and the
/// core's own — answers whether an in-place restart carries it
/// (#930 ruling 5). Discovered through the one id-container
/// walker `WindowRekeyParityTests` reads (`idContainers`), over a
/// desk that populates every store the fixture can reach, and
/// each found path must sit in the register below with its
/// carry and reason. `SnapshotCarryCensusTests` holds the per-
/// field round trip of `Space` and `ManagedWindow`; this suite
/// holds the stores around them.
///
/// Stated limits, the walker's: a store is seen only while it
/// holds an entry, so one the fixture cannot populate reaches the
/// register only through review — the resolution clause below
/// keeps every register entry naming a live property, never the
/// reverse; and a store deeper than the walker's depth is unseen.
@Suite("In-place snapshot store census (#930)", .serialized)
@MainActor
struct SnapshotStoreCensusTests {
    enum Carry {
        /// Every snapshot carries it.
        case always
        /// Only the in-place snapshot carries it.
        case inPlace
        /// Every stop's snapshot carries it — a quit's and an
        /// in-place one — never an autosave (#1864).
        case stop
        /// Nothing carries it.
        case behind
    }

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
        "drawnSpaceModes":
            (.behind, "settled by the replay itself (#1177)"),
        "tiler.placements.entries":
            (.behind, "an age-bounded echo ledger (#1161)"),
        "tiler.applier.instantTargets.entries":
            (.behind, "an age-bounded echo ledger (#881)"),
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
        "borders.markTracked": (.behind, "render state, redrawn"),
        "stickyMarks.overlays": (.behind, "render state, redrawn"),
    ]

    /// A desk populating every store the fixture can reach.
    private func desk() throws -> KiwiCore {
        let shown = F.shown
        let hidden = F.hidden
        let windows: [F.Window] = [
            .init(
                id: WindowID(1),
                space: shown,
                frame: CGRect(x: 10, y: 40, width: 500, height: 400)
            ),
            .init(
                id: WindowID(2),
                space: shown,
                frame: CGRect(x: 90, y: 90, width: 500, height: 400)
            ),
            .init(
                id: WindowID(3),
                space: hidden,
                frame: CGRect(x: 90, y: 90, width: 500, height: 400),
                floating: true
            ),
            .init(
                id: WindowID(4),
                space: hidden,
                frame: CGRect(x: 60, y: 70, width: 500, height: 400)
            ),
        ]
        let core = try #require(F.processA(windows))
        core.setSpaceMode(shown, .stack)
        core.state.workspaces.withSpace(shown) {
            $0.stackWeights = [WindowID(2): 1.5]
        }
        core.state.setFloating(WindowID(3), true)
        core.state.setSticky(WindowID(2), .display)
        core.state.stickyReachOverrides[WindowID(2)] = true
        core.state.floatFrames[WindowID(1)] = .init(pid: 7, frame: .zero)
        core.state.remember(WindowID(9), in: shown)
        core.state.restoredFrames[WindowID(9)] = .init(
            frame: .zero,
            floating: true
        )
        core.state.departedSlots[WindowID(9)] = .init(rank: 0)
        core.state.closedDepartures.insert(WindowID(9))
        core.state.focusRecency[WindowID(1)] = .init(pid: 7, tick: 1)
        core.tiler.monocleShownMembers[shown] = WindowID(1)
        core.ownFronts[WindowID(1)] = core.wallClock()
        core.state.crossSession.placed.insert(WindowID(1))
        core.state.profilePartitioning.record(
            [Space(id: hidden, windows: [WindowID(4)])],
            as: .profile("Other")
        )
        core.state.heldSpaces[hidden] = HeldOrigin(
            name: hidden,
            screen: "DELL:1920x1080",
            icon: nil,
            arrangement: nil
        )
        _ = F.settle(core)
        // After the settle, whose retire prunes an arm on a Space
        // no live profile leaves temporary.
        core.state.temporaryArmed.insert(shown)
        // A departure owed (#1508): the hidden Space leaves view.
        _ = core.tiler.stashDepartures.pass(
            shown: [shown, hidden],
            forcing: false
        )
        _ = core.tiler.stashDepartures.pass(
            shown: [shown],
            forcing: false
        )
        return core
    }

    @Test(
        "every id-keyed store is carried or classified",
        .enabled(if: NSScreen.main != nil)
    )
    func everyStoreIsClassified() throws {
        let core = try desk()
        let found = idContainers(
            core,
            isID: { $0 is WindowID || $0 is SpaceID }
        )
        let paths = Set(found.map(\.path))
        // Non-vacuous: the stores the ruling names were reached.
        for named in [
            "state.floatFrames", "tiler.boundLearner.lastAsks",
            "state.userFloated", "tiler.monocleShownMembers",
            "state.heldSpaces", "state.temporaryArmed", "ownFronts",
            "tiler.stashDepartures.owed",
            "state.profilePartitioning.byArrangement[][]",
            "state.crossSession.placed",
        ] {
            #expect(paths.contains(named), "\(named) was not reached")
        }
        let unclassified = paths.filter { Self.register[$0] == nil }
        #expect(
            unclassified.isEmpty,
            """
            id-keyed stores with no in-place answer: \
            \(unclassified.sorted()) — carry them in \
            StateSnapshot+InPlace or classify them here (#930)
            """
        )
    }

    /// Every register entry names a property that exists, so a
    /// renamed store cannot leave a stale answer behind.
    @Test("every register entry resolves to a live property")
    func registerResolves() {
        let core = makeTestCore()
        for path in Self.register.keys {
            let labels = path.split(separator: ".")
                .map { $0.replacingOccurrences(of: "[]", with: "") }
            var value: Any = core
            var resolved = true
            for (index, label) in labels.enumerated() {
                if index > 0,
                    path.split(separator: ".")[index - 1]
                        .hasSuffix("[]")
                {
                    // Past a dictionary value: the element type is
                    // `Space`, whose fields the Space census holds.
                    value = Space(id: SpaceID("1"))
                }
                guard
                    let child = Mirror(reflecting: value).children
                        .first(where: { $0.label == label })
                else {
                    resolved = false
                    break
                }
                value = child.value
            }
            #expect(resolved, "\(path) names no live property")
        }
    }
}
