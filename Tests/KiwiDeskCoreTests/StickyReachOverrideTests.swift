import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The `override_sticky_reach` verb, the effective verdict and
/// the pin's lifetime — through a real core, with the bridge
/// pinned ABSENT via the resolver seam: another suite's
/// `classResolverOverride` can leave `WMBridge.isAvailable`'s
/// process cache true in a full run, so "the carry is inert" is
/// asserted, never assumed. The carry itself is
/// `StickyReachCarryTests`'.
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

    /// A minimize keeps the id and the scope, and a hide keeps
    /// the window (#913), so the pin survives both; a genuine
    /// close drops it — old ids get recycled onto unrelated
    /// windows.
    @Test("only a genuine close drops the pin")
    func minimizeAndHideKeepThePin() {
        defer { reset() }
        let core = makeCore()
        let id = WindowID(1)
        core.state.stickyReachOverrides[id] = false
        core.handle(.windowDestroyed(id, wasMinimized: true))
        #expect(core.state.stickyReachOverrides[id] == false)
        core.handle(.windowHidden(id))
        #expect(core.state.stickyReachOverrides[id] == false)
        core.handle(.windowDestroyed(id, wasMinimized: false))
        #expect(core.state.stickyReachOverrides[id] == nil)
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

    /// Without the bridge nothing is carried, so the removal
    /// gate has nothing to distrust — a vanish is a vanish.
    @Test("no bridge, no carried set")
    func absentBridgeCarriesNothing() {
        defer { reset() }
        let core = makeCore()
        core.state.setSticky(WindowID(1), .global)
        #expect(core.stickyReachCarried().isEmpty)
        #expect(core.eventLoop.carriedWindows().isEmpty)
    }
}
