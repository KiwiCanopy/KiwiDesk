import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

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

    /// Seeds the ledger through its own reconcile — the one
    /// writer — with always-accepting fakes. One call: a second
    /// reconcile would retire whatever the first asserted.
    private func seed(
        _ core: KiwiCore,
        _ wanted: [WindowID: Set<SkyLight.SpaceID>]
    ) {
        core.stickyReach.reconcile(
            wanted: wanted,
            homes: [:],
            add: { _, _ in true },
            remove: { _, _ in true }
        )
    }

    /// The one forget rule (re-review round 3): only ids the
    /// WindowServer itself forgot. A minimize is a
    /// `windowDestroyed(wasMinimized: true)` whose window still
    /// exists with its memberships — forgetting there orphans
    /// them past `retireStickyReach`'s reach at quit.
    @Test("only a genuine close forgets the ledger")
    func minimizeKeepsTheLedger() {
        defer { reset() }
        let core = makeCore()
        let id = WindowID(1)
        seed(core, [id: [10]])
        core.handle(.windowDestroyed(id, wasMinimized: true))
        #expect(core.stickyReach.asserted[id] == [10])
        core.handle(.windowDestroyed(id, wasMinimized: false))
        #expect(core.stickyReach.asserted.isEmpty)
    }

    /// Termination forgets exactly the ids that died with its
    /// pid — never every state-absent id, which also matches a
    /// minimized window of another app.
    @Test("termination forgets its own pid's ids alone")
    func terminationForgetsItsOwnPid() {
        defer { reset() }
        let core = makeCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(2),
                    pid: 2,
                    appName: "App2"
                )
            )
        )
        seed(core, [WindowID(1): [10], WindowID(2): [11]])
        // App 2's window is minimized (state-absent, alive)…
        core.handle(
            .windowDestroyed(WindowID(2), wasMinimized: true)
        )
        // …and app 1 terminates: only ITS id is forgotten.
        core.handle(.appTerminated(pid: 1))
        #expect(core.stickyReach.asserted[WindowID(1)] == nil)
        #expect(core.stickyReach.asserted[WindowID(2)] == [11])
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
