import Foundation
import Testing

@testable import KiwiDeskCore

/// The layout-cycle plate's Core half (#2144): `cycle_mode` alone
/// pays a cue — naming the Space's screen, the cycle list and the
/// layout it landed on — and only once its write landed; the
/// app-wide `mode.cue` switch turns it off.
@Suite("Layout-cycle cue (#2144)")
@MainActor
struct ModeCycleCueTests {
    private func makeCore() -> (KiwiCore, Box) {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.activate("1")
        core.state.workspaces.setMode("1", .bsp)
        let box = Box()
        core.onModeCue = { box.cues.append($0) }
        return (core, box)
    }

    final class Box { var cues: [ModeCycleCue] = [] }

    @Test("a press names the screen, the list and the new layout")
    func pressPaysTheCue() {
        let (core, box) = makeCore()
        #expect(core.execute("cycle_mode", args: []).isSuccess)
        #expect(
            box.cues == [
                ModeCycleCue(
                    display: DisplayID(1),
                    cycle: [.bsp, .scrolling, .floating],
                    current: .scrolling
                )
            ]
        )
    }

    /// The press asked for it; a Layout-menu pick or a Lua
    /// `set_mode` changes the layout without one.
    @Test("set_mode shows nothing")
    func setModeShowsNothing() {
        let (core, box) = makeCore()
        _ = core.execute("set_mode", args: [.string("grid")])
        #expect(box.cues.isEmpty)
    }

    @Test("a refused press shows nothing")
    func refusalShowsNothing() {
        let (core, box) = makeCore()
        _ = core.execute("cycle_mode", args: [.string("sideways")])
        #expect(box.cues.isEmpty)
    }

    @Test("set_mode_cue(false) turns it off for the session")
    func verbTurnsItOff() {
        let (core, box) = makeCore()
        #expect(core.appWide.modeCue)
        let off = core.execute("set_mode_cue", args: [.bool(false)])
        #expect(off.isSuccess)
        #expect(core.appWide.modeCue == false)
        _ = core.execute("cycle_mode", args: [])
        #expect(box.cues.isEmpty)
        #expect(!core.execute("set_mode_cue", args: []).isSuccess)
    }

    @Test("gui.json carries mode.cue, and its absence reads on")
    func storedShape() throws {
        var config = GuiConfig()
        var value = AppWideSettings()
        value.modeCue = false
        config.appWide = value
        let data = try JSONEncoder().encode(config)
        let root = try #require(
            try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        )
        let group = try #require(root["mode"] as? [String: Any])
        #expect(group["cue"] as? Bool == false)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.appWide?.modeCue == false)
        var older = root
        older["mode"] = nil
        let legacy = try JSONDecoder().decode(
            GuiConfig.self,
            from: JSONSerialization.data(withJSONObject: older)
        )
        #expect(legacy.appWide?.modeCue == true)
    }
}
