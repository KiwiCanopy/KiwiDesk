import Foundation
import Testing

@testable import KiwiDeskCore

/// The layout-cycle plate's Core half (#2144) that reads no
/// stand-down: `set_mode` and a refused press pay nothing, and
/// the switch's stored shape. The press itself reads the
/// process-global `isUser` override, so its cases live in
/// `FullscreenStandDownTests+ModeCue`.
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

    /// The press asked for it; a Layout-menu pick or a Lua
    /// `set_mode` changes the layout without one.
    @Test("set_mode shows nothing")
    func setModeShowsNothing() {
        let (core, box) = makeCore()
        #expect(
            core.execute("set_mode", args: [.string("grid")]).isSuccess
        )
        #expect(box.cues.isEmpty)
    }

    @Test("a refused press shows nothing")
    func refusalShowsNothing() {
        let (core, box) = makeCore()
        let refused = core.execute(
            "cycle_mode",
            args: [.string("sideways")]
        )
        #expect(!refused.isSuccess)
        #expect(box.cues.isEmpty)
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
