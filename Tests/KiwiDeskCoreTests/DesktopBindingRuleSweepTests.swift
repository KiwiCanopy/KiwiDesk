import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bound Desktop's profile apply leaves its window-rule sweep to
/// the switch's own folded `reconcileAll` (#2347), which
/// `DesktopSwitchRuleSweepSeamTests` holds to follow the handler.
/// Read through `WorkMeter.shared`'s bulk count, as a delta over
/// one synchronous stretch no other suite can interleave.
/// Over the #888 fixture's main screen: Desktops 1–2 (ids 10, 11)
/// on `UUID-A`.
@Suite("A bound Desktop's apply defers its rule sweep (#2347)", .serialized)
@MainActor
struct DesktopBindingRuleSweepTests {
    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["D1:100x100"])],
            isDefault: false,
            spaceModes: ["1": .bsp],
            settings: TilingSettings()
        )
    }

    /// "Work" and "Other" saved for the one 100x100 screen,
    /// "Other" loaded, and Desktop 2 bound to "Work".
    private func makeCore() throws -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { desktopVerbBridgeClasses[$0] }
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-sweep-\(UUID().uuidString)")
        )
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "D1",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        for name in ["Work", "Other"] {
            try core.profiles.save(profile(name))
        }
        core.execute("load_profile", args: [.string("Other")])
        core.execute(
            "bind_profile_to_desktop",
            args: [.number(2), .string("Work")]
        )
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private var bulkReconciles: Int {
        WorkMeter.shared.snapshot(reset: false).counts.bulkReconciles
    }

    @Test("a bound switch loads its profile with no sweep of its own")
    func boundSwitchSweepsNothing() throws {
        defer { teardown() }
        let core = try makeCore()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 11
        let before = bulkReconciles
        core.handleDesktopChange()
        #expect(core.profiles.currentName == "Work")
        #expect(bulkReconciles - before == 0)
        #expect(!core.defersRuleSweepToSwitchPass)
    }

    @Test("a profile load outside a switch still sweeps once")
    func loadStillSweeps() throws {
        defer { teardown() }
        let core = try makeCore()
        let before = bulkReconciles
        core.execute("load_profile", args: [.string("Work")])
        #expect(core.profiles.currentName == "Work")
        #expect(bulkReconciles - before == 1)
    }
}
