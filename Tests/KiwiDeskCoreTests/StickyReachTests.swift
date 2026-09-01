import Foundation
import Testing

@testable import KiwiDeskCore

/// The sticky Desktop-reach ledger (#1145) — the pure half; the
/// bridge dispatch it drives is pinned by
/// `StickyReachWiringTests`, since no unit test can reach a live
/// `WMBridge` (os-private-apis.md).
@Suite("Sticky reach ledger")
struct StickyReachLedgerTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    /// A reconcile driver whose dispatch accepts everything and
    /// records what was asked.
    private struct Drive {
        var added: [WindowID: Set<SkyLight.SpaceID>] = [:]
        var removed: [WindowID: Set<SkyLight.SpaceID>] = [:]

        mutating func run(
            _ reach: inout StickyReach,
            wanted: [WindowID: Set<SkyLight.SpaceID>],
            homes: [WindowID: Set<SkyLight.SpaceID>] = [:],
            acceptAdd: Bool = true,
            acceptRemove: Bool = true
        ) {
            added = [:]
            removed = [:]
            reach.reconcile(
                wanted: wanted,
                homes: homes,
                add: { id, spaces in
                    added[id, default: []].formUnion(spaces)
                    return acceptAdd
                },
                remove: { id, spaces in
                    removed[id, default: []].formUnion(spaces)
                    return acceptRemove
                }
            )
        }
    }

    @Test("first reconcile asserts everything wanted")
    func firstReconcileAddsAll() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10, 11]])
        #expect(drive.added == [w1: [10, 11]])
        #expect(drive.removed.isEmpty)
        #expect(reach.asserted == [w1: [10, 11]])
    }

    @Test("an unchanged reconcile dispatches nothing")
    func unchangedReconcileIsEmpty() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10, 11]])
        drive.run(&reach, wanted: [w1: [10, 11]])
        #expect(drive.added.isEmpty)
        #expect(drive.removed.isEmpty)
    }

    @Test("a narrowed want removes exactly the dropped spaces")
    func narrowedWantRemovesTheDifference() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10, 11, 12]])
        drive.run(&reach, wanted: [w1: [10]])
        #expect(drive.added.isEmpty)
        #expect(drive.removed == [w1: [11, 12]])
        #expect(reach.asserted == [w1: [10]])
    }

    /// Unsticky, an off toggle, an off override and a rekeyed-out
    /// id all take this one door: the window leaves `wanted`.
    @Test("a window absent from wanted retires wholesale")
    func absentWindowRetires() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10], w2: [11]])
        drive.run(&reach, wanted: [w2: [11]])
        #expect(drive.removed == [w1: [10]])
        #expect(reach.asserted == [w2: [11]])
    }

    /// A refused add must NOT be recorded — believed-but-never-
    /// dispatched is a membership `retire` can never take back,
    /// and recording it also stops the re-issue that makes the
    /// refresh idempotent (#1145 review).
    @Test("a refused add re-issues on the next reconcile")
    func refusedAddReissues() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10]], acceptAdd: false)
        #expect(reach.asserted.isEmpty)
        drive.run(&reach, wanted: [w1: [10]])
        #expect(drive.added == [w1: [10]])
        #expect(reach.asserted == [w1: [10]])
    }

    @Test("a refused removal stays asserted and retries")
    func refusedRemovalRetries() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10]])
        drive.run(&reach, wanted: [:], acceptRemove: false)
        #expect(reach.asserted == [w1: [10]])
        drive.run(&reach, wanted: [:])
        #expect(drive.removed == [w1: [10]])
        #expect(reach.asserted.isEmpty)
    }

    /// The window's own memberships are untouchable in BOTH
    /// directions: never added (a no-op ask) and never removed
    /// (a removal there takes the window off its own Desktop) —
    /// and a home that migrated INTO an asserted space stays
    /// asserted, so it is reclaimable if the home later leaves.
    @Test("the home set is excluded both ways and retained")
    func homeIsExcludedAndRetained() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10, 11]], homes: [w1: [10]])
        #expect(drive.added == [w1: [11]])
        #expect(reach.asserted == [w1: [11]])
        // The user moves the window onto Desktop 11 (home
        // migrates into the asserted space); an unsticky must
        // not remove it from where it now lives…
        drive.run(&reach, wanted: [:], homes: [w1: [11]])
        #expect(drive.removed.isEmpty)
        #expect(reach.asserted == [w1: [11]])
        // …and once the home moves away again, the leftover is
        // still on the ledger for a genuine retire.
        drive.run(&reach, wanted: [:], homes: [w1: [12]])
        #expect(drive.removed == [w1: [11]])
        #expect(reach.asserted.isEmpty)
    }

    /// A destroyed window's memberships died with it — no
    /// removal is dispatched at a dead id.
    @Test("forget drops the ledger without a step")
    func forgetDropsWithoutDispatch() {
        var reach = StickyReach()
        var drive = Drive()
        drive.run(&reach, wanted: [w1: [10]])
        reach.forget(w1)
        #expect(reach.asserted.isEmpty)
        drive.run(&reach, wanted: [:])
        #expect(drive.removed.isEmpty)
    }
}

@Suite("Sticky reach wanted spaces")
struct StickyReachWantedTests {
    /// Two screens, two user Desktops each, plus a fullscreen
    /// space Mission Control does not count.
    private let spaces: [NativeSpace] = [
        NativeSpace(id: 10, displayUUID: "A", isCurrent: true),
        NativeSpace(id: 11, displayUUID: "A", isCurrent: false),
        NativeSpace(
            id: 12,
            displayUUID: "A",
            isCurrent: false,
            isUser: false
        ),
        NativeSpace(id: 20, displayUUID: "B", isCurrent: true),
        NativeSpace(id: 21, displayUUID: "B", isCurrent: false),
    ]

    @Test("global reach wants every user Desktop")
    func globalWantsEverything() {
        #expect(
            StickyReach.wantedSpaces(
                scope: .global,
                homeDisplayUUID: "A",
                in: spaces
            ) == [10, 11, 20, 21]
        )
    }

    @Test("display reach stays on the home screen's Desktops")
    func displayStaysOnItsScreen() {
        #expect(
            StickyReach.wantedSpaces(
                scope: .display,
                homeDisplayUUID: "B",
                in: spaces
            ) == [20, 21]
        )
    }

    /// Shared-Spaces mode carries one display record whose
    /// identifier is no screen's UUID — one list means 📌 and ∞
    /// coincide, rather than 📌 silently matching nothing
    /// (#1145 review).
    @Test("one display record means 📌 takes the whole pool")
    func sharedModeFallsBackToThePool() {
        let shared: [NativeSpace] = [
            NativeSpace(id: 1, displayUUID: "Main", isCurrent: true),
            NativeSpace(id: 2, displayUUID: "Main", isCurrent: false),
        ]
        #expect(
            StickyReach.wantedSpaces(
                scope: .display,
                homeDisplayUUID: "CG-UUID-NOWHERE",
                in: shared
            ) == [1, 2]
        )
    }

    /// A fullscreen/system space is never a target — a window
    /// added there would surface behind a fullscreen app.
    @Test("non-user spaces are never wanted")
    func nonUserSpacesExcluded() {
        let wanted = StickyReach.wantedSpaces(
            scope: .global,
            homeDisplayUUID: "A",
            in: spaces
        )
        #expect(!wanted.isEmpty)
        #expect(!wanted.contains(12))
    }

    @Test("no scope, or no home display for 📌, wants nothing")
    func degenerateCasesWantNothing() {
        #expect(
            StickyReach.wantedSpaces(
                scope: .none,
                homeDisplayUUID: "A",
                in: spaces
            ).isEmpty
        )
        #expect(
            StickyReach.wantedSpaces(
                scope: .display,
                homeDisplayUUID: nil,
                in: spaces
            ).isEmpty
        )
    }
}

/// The `override_sticky_reach` verb and the effective verdict —
/// through a real core, with the bridge pinned ABSENT via the
/// resolver seam: another suite's `classResolverOverride` can
/// leave `WMBridge.isAvailable`'s process cache true in a full
/// run, so "the refresh is inert" is asserted, never assumed.
@Suite("Sticky reach override verb", .serialized)
@MainActor
struct StickyReachOverrideTests {
    /// Saved so `reset()` restores rather than clears — another
    /// suite's installed resolver must survive this one
    /// (tests.md ▸ process-global state).
    private static var priorResolver: ((String) -> AnyClass?)?

    private func makeCore() -> KiwiCore {
        Self.priorResolver = WMBridge.classResolverOverride
        WMBridge.classResolverOverride = { _ in nil }
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-reach-\(UUID().uuidString)"
                )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(1),
                    pid: 1,
                    appName: "App1"
                )
            )
        )
        return core
    }

    private func reset() {
        WMBridge.classResolverOverride = Self.priorResolver
        Self.priorResolver = nil
    }

    @Test("on, off and auto write the focused window's verdict")
    func overrideWritesResolve() {
        defer { reset() }
        let core = makeCore()
        let id = WindowID(1)
        #expect(core.stickyReachEnabled(for: id))
        #expect(
            core.execute(
                "override_sticky_reach",
                args: [.string("off")]
            ).isSuccess
        )
        #expect(!core.stickyReachEnabled(for: id))
        // The override outranks the global toggle in BOTH
        // directions.
        core.tiler.settings.stickyStyle.desktopReach = false
        #expect(
            core.execute(
                "override_sticky_reach",
                args: [.string("on")]
            ).isSuccess
        )
        #expect(core.stickyReachEnabled(for: id))
        // `auto` returns the window to the toggle.
        #expect(
            core.execute(
                "override_sticky_reach",
                args: [.string("auto")]
            ).isSuccess
        )
        #expect(!core.stickyReachEnabled(for: id))
    }

    @Test("a bad value is rejected off the enum's own cases")
    func badValueRejectsWithTheDerivedList() {
        defer { reset() }
        let core = makeCore()
        let response = core.execute(
            "override_sticky_reach",
            args: [.string("sideways")]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error
                == "expected \(StickyReachOverride.expectedList)"
        )
    }

    @Test("the global toggle rides sticky.set_desktop_reach")
    func toggleWritesTheStyle() {
        defer { reset() }
        let core = makeCore()
        #expect(
            core.execute(
                "sticky.set_desktop_reach",
                args: [.bool(false)]
            ).isSuccess
        )
        #expect(
            !core.tiler.settings.stickyStyle.desktopReach
        )
        #expect(!core.stickyReachEnabled(for: WindowID(1)))
    }
}
