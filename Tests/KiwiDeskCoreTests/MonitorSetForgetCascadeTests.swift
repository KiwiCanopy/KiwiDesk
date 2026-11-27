import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory:
            testTemporaryDirectory
            .appendingPathComponent("kiwi-cascade-\(UUID().uuidString)")
    )
}

@MainActor
private func connect(_ core: KiwiCore, _ names: [String]) {
    for display in core.state.workspaces.allDisplays {
        core.state.workspaces.removeDisplay(display.id)
    }
    for (index, name) in names.enumerated() {
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(UInt32(index + 1)),
                name: name,
                frame: CGRect(
                    x: CGFloat(index) * 100,
                    y: 0,
                    width: 100,
                    height: 100
                )
            )
        )
    }
}

private func fp(_ names: String...) -> [String] {
    names.map { "\($0):100x100" }.sorted()
}

/// What a forget leaves behind is cleared with it (#3324): the
/// stored Desktop binding entries scoped to the setup, and the
/// holder's per-screen bar edges for areas its splits no longer hold;
/// a screen number within the profile's count keeps its own (#3647).
@Suite("A forgotten setup's leftovers go (#3324)", .serialized)
@MainActor
struct MonitorSetForgetCascadeTests {
    /// "Desk" on A+B, then on A+C (connected), with a Space Bar
    /// edge of its own on Screens 1 and 2 and on an area no split
    /// holds.
    private func desk(_ core: KiwiCore) throws {
        core.tiler.settings.spaceBarStyle.edgeOverride = [
            "1": .left, "2": .right, "2#3": .bottom,
        ]
        core.tiler.settings.appBarStyle.edgeOverride = ["2": .top]
        connect(core, ["A", "B"])
        try core.persistProfile(named: "Desk", modes: nil)
        connect(core, ["A", "C"])
        try core.persistProfile(named: "Desk", modes: nil)
    }

    @Test("an area no split holds loses its bar edge; numbers stay")
    func strayEdgesGo() throws {
        let core = makeCore()
        try desk(core)
        try core.forgetMonitorSet(fp("A", "B"))
        let stored = try core.profiles.read(name: "Desk")
        let kept: [String: AppBarEdge] = ["1": .left, "2": .right]
        #expect(stored.settings.spaceBarStyle.edgeOverride == kept)
        #expect(stored.settings.appBarStyle.edgeOverride == ["2": .top])
        // The live copy too, or the next Save writes it back.
        #expect(core.tiler.settings.spaceBarStyle.edgeOverride == kept)
    }

    @Test("bindings scoped to the setup go; an all-setups entry stays")
    func scopedBindingsGo() throws {
        let core = makeCore()
        try desk(core)
        try core.guiConfigStore.save(GuiConfig())
        let scoped = core.bindingEntry(named: "Desk", setup: fp("A", "B"))
        let kept = core.bindingEntry(named: "Desk", setup: fp("A", "C"))
        let all = core.bindingEntry(named: "Desk")
        try core.rewriteSidecarBindings { map in
            map[.number(1)] = DesktopBinding(entries: [scoped], desktop: 1)
            map[.number(2)] = DesktopBinding(
                entries: [scoped, kept, all],
                desktop: 2
            )
        }
        try core.forgetMonitorSet(fp("A", "B"))
        let map = core.guiConfigStore.bindingsFile.load().profileBindings
        #expect(map[.number(1)] == nil)
        #expect(map[.number(2)]?.entries.map(\.setup) == [fp("A", "C"), nil])
    }

    @Test("a hand-written config has no stored bindings to follow")
    func noSidecarIsFine() throws {
        let core = makeCore()
        try desk(core)
        #expect(!core.guiConfigStore.exists)
        #expect(try core.forgetMonitorSet(fp("A", "B")) == ["Desk"])
    }

    @Test("the binding algebra drops only that scope")
    func algebra() {
        var binding = DesktopBinding(
            entries: [
                DesktopBinding.Entry(name: "Desk", setup: fp("B", "A")),
                DesktopBinding.Entry(name: "Desk"),
            ],
            desktop: 1
        )
        let emptied = binding.unbind(setup: fp("A", "B"))
        #expect(!emptied)
        #expect(binding.entries.map(\.setup) == [nil])
        let allKept = binding.unbind(setup: [])
        #expect(!allKept)
        #expect(binding.entries.count == 1)
    }
}
