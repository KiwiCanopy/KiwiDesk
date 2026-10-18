import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A binding written through its own door takes effect at once
/// (#2324): before bindings left `gui.json` the write reloaded the
/// config, whose load applies the main Desktop's binding; the door
/// keeps that, so rebinding the current Desktop in Settings loads
/// the new profile at Save.
///
/// `.serialized`: the topology overrides are process-global.
@MainActor
@Suite("Desktop binding applies on its write (#2324)", .serialized)
struct DesktopBindingApplyOnWriteTests {
    private let stamp = DesktopIdentity(raw: "STAMP-W2")

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: ["D1:100x100"])],
            spaceModes: ["1": .bsp],
            settings: TilingSettings()
        )
    }

    private func pinTopology() {
        NativeSpaces.spacesOverride = [
            NativeSpace(
                id: 11,
                displayUUID: "UUID-A",
                isCurrent: true,
                identity: stamp
            )
        ]
        NativeSpaces.mainDisplayUUIDOverride = "UUID-A"
        NativeSpaces.activeSpaceIDOverride = 11
    }

    /// The one screen the profiles are saved for, or the gate stands
    /// aside on an unknown screen count.
    private func connectScreen(_ core: KiwiCore) {
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "D1",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
    }

    private func reset() {
        NativeSpaces.spacesOverride = nil
        NativeSpaces.mainDisplayUUIDOverride = nil
        NativeSpaces.activeSpaceIDOverride = nil
    }

    @Test("rebinding the current Desktop loads the profile at the write")
    func rebindAppliesAtTheWrite() throws {
        defer { reset() }
        pinTopology()
        let core = makeTestCore()
        connectScreen(core)
        try core.guiConfigStore.save(GuiConfig())
        core.loadConfig()
        try #require(core.lua != nil)
        for name in ["Laptop", "Other"] {
            try core.profiles.save(profile(name))
        }
        core.execute("load_profile", args: [.string("Other")])
        #expect(core.profiles.currentName == "Other")
        try core.rewriteSidecarBindings { map in
            map[.identity(stamp)] = DesktopBinding(
                entries: [core.bindingEntry(named: "Laptop")],
                desktop: 1
            )
        }
        #expect(core.profiles.currentName == "Laptop")
    }

    /// A paused cold boot has no engine yet: the write files the
    /// binding and leaves the load to the start that follows.
    @Test("a write before the engine starts loads nothing")
    func pausedBootDefers() throws {
        defer { reset() }
        pinTopology()
        let core = makeTestCore()
        connectScreen(core)
        try core.guiConfigStore.save(GuiConfig())
        #expect(core.lua == nil)
        for name in ["Laptop", "Other"] {
            try core.profiles.save(profile(name))
        }
        #expect(core.profiles.currentName == "Other")
        try core.rewriteSidecarBindings { map in
            map[.identity(stamp)] = DesktopBinding(
                entries: [core.bindingEntry(named: "Laptop")],
                desktop: 1
            )
        }
        #expect(core.profiles.currentName == "Other")
        #expect(
            core.guiConfigStore.bindingsFile.load()
                .profileBindings[.identity(stamp)] != nil
        )
    }
}
