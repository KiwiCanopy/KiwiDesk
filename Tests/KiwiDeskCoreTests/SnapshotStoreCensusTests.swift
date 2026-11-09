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
/// each found path must sit in the register with its
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

    // The register is `SnapshotStoreCensusTests+Register.swift`,
    // split at the 350-line ceiling.

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
        core.setSpaceMode(shown, .stack, keepingSizes: false)
        core.state.workspaces.withSpace(shown) {
            $0.stackWeights = [WindowID(2): 1.5]
        }
        core.state.setFloating(WindowID(3), true)
        core.state.setSticky(WindowID(2), .display)
        core.state.stickyReachOverrides[WindowID(2)] = true
        core.state.floatFrames[WindowID(1)] = .init(pid: 7, frame: .zero)
        core.state.floatAspects[WindowID(1)] = .init(pid: 7, ratio: 1.5)
        core.state.tiledOverRule[WindowID(1)] = 7
        core.windowCreates.noteCreated(WindowID(1), at: core.wallClock())
        for raw: UInt32 in [2, 3] {
            core.arrivals.hold(
                .init(
                    window: ManagedWindow(
                        id: WindowID(raw),
                        pid: 7,
                        appName: "App"
                    ),
                    space: nil,
                    eventOwed: true,
                    axCreate: false,
                    at: core.wallClock()
                )
            )
        }
        _ = core.arrivals.land(WindowID(3), at: core.wallClock())
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
        core.desktopMemory.stackFlips[nil] = [shown: .left]
        var sized = SessionRatios()
        sized.masterRatio = 0.6
        core.desktopMemory.sessionRatios[nil] = [nil: [shown: sized]]
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
        // After the settle too, whose pass pays an unheld return.
        core.state.maximizedFloatReturn[WindowID(1)] = .init(
            pid: 7,
            frame: .zero
        )
        // A departure owed (#1508): the hidden Space leaves view.
        _ = core.tiler.stashDepartures.pass(
            shown: [shown, hidden],
            forcing: false
        )
        _ = core.tiler.stashDepartures.pass(
            shown: [shown],
            forcing: false
        )
        // A direct write owed while the hand moves (#2627).
        core.tiler.motionGate.quiescence.sinceMouseMoved = { 0 }
        _ = core.tiler.motionGate.owe(.floatPlacement, for: WindowID(1))
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
            "state.floatFrames", "state.tiledOverRule",
            "state.maximizedFloatReturn",
            "tiler.boundLearner.lastAsks",
            "state.userFloated", "tiler.monocleShownMembers",
            "state.heldSpaces", "state.temporaryArmed", "ownFronts",
            "tiler.stashDepartures.owed", "tiler.motionGate.owedWrites",
            "state.profilePartitioning.byArrangement[][]",
            "state.crossSession.placed", "desktopMemory.stackFlips[]",
            "desktopMemory.sessionRatios[][]",
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
                    // `Space`, whose fields the Space census holds —
                    // save the Space history's trails (#1655).
                    value =
                        path.hasPrefix("spaceHistory.")
                        ? SpaceHistory.Trail() as Any
                        : Space(id: SpaceID("1"))
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
