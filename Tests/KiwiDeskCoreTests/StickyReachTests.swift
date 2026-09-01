import Foundation
import Testing

@testable import KiwiDeskCore

/// The sticky Desktop-reach ledger and its wanted-set derivation
/// (#1145) — pure halves; the bridge dispatch they drive is
/// pinned by `StickyReachWiringTests`, since no unit test can
/// reach a live `WMBridge` (os-private-apis.md).
@Suite("Sticky reach ledger")
struct StickyReachLedgerTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)

    @Test("first reconcile asserts everything wanted")
    func firstReconcileAddsAll() {
        var reach = StickyReach()
        let step = reach.reconcile(wanted: [w1: [10, 11]])
        #expect(step.add == [w1: [10, 11]])
        #expect(step.remove.isEmpty)
        #expect(reach.asserted == [w1: [10, 11]])
    }

    @Test("an unchanged reconcile dispatches nothing")
    func unchangedReconcileIsEmpty() {
        var reach = StickyReach()
        _ = reach.reconcile(wanted: [w1: [10, 11]])
        let step = reach.reconcile(wanted: [w1: [10, 11]])
        #expect(step.isEmpty)
    }

    @Test("a narrowed want removes exactly the dropped spaces")
    func narrowedWantRemovesTheDifference() {
        var reach = StickyReach()
        _ = reach.reconcile(wanted: [w1: [10, 11, 12]])
        let step = reach.reconcile(wanted: [w1: [10]])
        #expect(step.add.isEmpty)
        #expect(step.remove == [w1: [11, 12]])
        #expect(reach.asserted == [w1: [10]])
    }

    /// Unsticky, an off toggle, an off override and a rekeyed-out
    /// id all take this one door: the window leaves `wanted`.
    @Test("a window absent from wanted retires wholesale")
    func absentWindowRetires() {
        var reach = StickyReach()
        _ = reach.reconcile(wanted: [w1: [10], w2: [11]])
        let step = reach.reconcile(wanted: [w2: [11]])
        #expect(step.remove == [w1: [10]])
        #expect(reach.asserted == [w2: [11]])
    }

    /// A destroyed window's memberships died with it — no
    /// removal is dispatched at a dead id.
    @Test("forget drops the ledger without a step")
    func forgetDropsWithoutDispatch() {
        var reach = StickyReach()
        _ = reach.reconcile(wanted: [w1: [10]])
        reach.forget(w1)
        #expect(reach.asserted.isEmpty)
        let step = reach.reconcile(wanted: [:])
        #expect(step.isEmpty)
    }

    @Test("drainAll returns everything held and clears")
    func drainAllReturnsAndClears() {
        var reach = StickyReach()
        _ = reach.reconcile(wanted: [w1: [10], w2: [11, 12]])
        let drained = reach.drainAll()
        #expect(drained == [w1: [10], w2: [11, 12]])
        #expect(reach.asserted.isEmpty)
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

    @Test("global reach wants every user Desktop, less home")
    func globalWantsEverything() {
        #expect(
            StickyReach.wantedSpaces(
                scope: .global,
                homeDisplayUUID: "A",
                excluding: [10],
                in: spaces
            ) == [11, 20, 21]
        )
    }

    @Test("display reach stays on the home screen's Desktops")
    func displayStaysOnItsScreen() {
        #expect(
            StickyReach.wantedSpaces(
                scope: .display,
                homeDisplayUUID: "B",
                excluding: [20],
                in: spaces
            ) == [21]
        )
    }

    /// A fullscreen/system space is never a target — a window
    /// added there would surface behind a fullscreen app.
    @Test("non-user spaces are never wanted")
    func nonUserSpacesExcluded() {
        let wanted = StickyReach.wantedSpaces(
            scope: .global,
            homeDisplayUUID: "A",
            excluding: [],
            in: spaces
        )
        #expect(!wanted.contains(12))
    }

    @Test("no scope, or no home display for 📌, wants nothing")
    func degenerateCasesWantNothing() {
        #expect(
            StickyReach.wantedSpaces(
                scope: .none,
                homeDisplayUUID: "A",
                excluding: [],
                in: spaces
            ).isEmpty
        )
        #expect(
            StickyReach.wantedSpaces(
                scope: .display,
                homeDisplayUUID: nil,
                excluding: [],
                in: spaces
            ).isEmpty
        )
    }
}

/// The `override_sticky_reach` verb and the effective verdict —
/// through a real core with the bridge absent, which is exactly
/// the state every unit test runs in: the override map writes
/// either way, and the (inert) refresh proves the gate holds.
@Suite("Sticky reach override verb", .serialized)
@MainActor
struct StickyReachOverrideTests {
    private func makeCore() -> KiwiCore {
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

    @Test("on, off and auto write the focused window's verdict")
    func overrideWritesResolve() {
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
