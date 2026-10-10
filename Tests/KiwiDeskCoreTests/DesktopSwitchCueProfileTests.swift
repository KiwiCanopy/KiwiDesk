import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop cue's profile line (#2142): named only when the
/// switch's binding LOADED a profile, through the real
/// `focus_desktop` and switch handler — never the profile that
/// merely stayed live. Over the #888 fixture's main screen:
/// Desktops 1–2 (ids 10, 11) on `UUID-A`.
@Suite("Desktop switch cue profile line (#2142)", .serialized)
@MainActor
struct DesktopSwitchCueProfileTests {
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
    /// "Other" loaded, and Desktop 2 bound to `bound`.
    private func makeCore(binding bound: String) throws -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { desktopVerbBridgeClasses[$0] }
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-cue-\(UUID().uuidString)")
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
            args: [.number(2), .string(bound)]
        )
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func switchToDesktop2(_ core: KiwiCore) -> [DesktopSwitchCue] {
        var shown: [DesktopSwitchCue] = []
        core.desktopCue.onCue = { shown.append($0) }
        core.execute("focus_desktop", args: [.number(2)])
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 11
        core.handleDesktopChange()
        return shown
    }

    @Test("a binding that loads a profile names it")
    func loadedProfileIsNamed() throws {
        let core = try makeCore(binding: "Work")
        defer { teardown() }
        let shown = switchToDesktop2(core)
        #expect(core.profiles.currentName == "Work")
        #expect(shown.map(\.loadedProfile) == ["Work"])
    }

    @Test("a binding to the live profile names nothing")
    func liveProfileIsNotNamed() throws {
        let core = try makeCore(binding: "Other")
        defer { teardown() }
        let shown = switchToDesktop2(core)
        #expect(core.profiles.currentName == "Other")
        #expect(shown.count == 1)
        #expect(shown.map(\.loadedProfile) == [nil])
    }
}
