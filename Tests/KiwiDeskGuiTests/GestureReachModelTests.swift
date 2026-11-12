import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A gesture row's "Applies to" over the draft (#3225): the loaded
/// page shows its profile's own bindings while gui.json keeps the
/// base, a tick writes another profile's file, and a re-keyed row
/// takes its reach along.
@Suite("Gesture reach in the draft", .serialized)
@MainActor
struct GestureReachModelTests {
    private let own = GestureKey(.rightClick, [.control])
    private let lua = LuaAction(lua: "KiwiDesk.reload_config()", kind: .custom)

    /// Work (loaded) binds its own right click; Home is stored and
    /// follows the base.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.gesture = GestureMap([own: .bound(.run(lua))])
        try core.profiles.save(work)
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    @Test("the loaded page shows its own row; gui.json keeps the base")
    func loadedPageIsOwn() throws {
        let model = try makeModel()
        #expect(model.config.gesture[own] == .bound(.run(lua)))
        let row = try #require(model.gestureReach(own.spelling))
        #expect(!row.shared && row.users == ["Work"])
        #expect(model.sidecarConfig.gesture[own] == nil)
    }

    @Test("ticking Home writes Work's row into Home's file")
    func tickHome() throws {
        let model = try makeModel()
        model.setProfile(.gesture, own.spelling, "Home", true)
        model.updateActiveProfile()
        #expect(
            try model.core.profiles.read(name: "Home").gesture?[own]
                == .bound(.run(lua))
        )
        #expect(model.core.guiConfigStore.load()?.gesture[own] == nil)
    }

    @Test("a re-keyed row keeps its reach in every profile it held")
    func rekeyCarriesTheReach() throws {
        let model = try makeModel()
        model.setProfile(.gesture, own.spelling, "Home", true)
        model.updateActiveProfile()

        let moved = GestureKey(.rightClick, [.option])
        model.carryPick(.gesture, from: own.spelling, to: moved.spelling)
        model.config.gesture[own] = nil
        model.config.gesture[moved] = .bound(.run(lua))
        model.updateActiveProfile()

        for name in ["Work", "Home"] {
            let map = try model.core.profiles.read(name: name).gesture
            #expect(map?[moved] == .bound(.run(lua)), "\(name)")
            #expect(map?[own] == nil, "\(name)")
        }
        #expect(model.core.guiConfigStore.load()?.gesture[moved] == nil)
    }

    @Test("a listed re-key reads as one move row, its reach folded")
    func rekeyIsOneRow() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.setProfile(.gesture, own.spelling, "Home", true)
        model.updateActiveProfile()

        let moved = GestureKey(.rightClick, [.option])
        model.carryPick(.gesture, from: own.spelling, to: moved.spelling)
        model.config.gesture[own] = nil
        model.config.gesture[moved] = .bound(.run(lua))

        let rows = SettingsDiffRowSource.rows(for: model).filter {
            $0.key == .shortcuts(.gestureBindings)
        }
        #expect(rows.count == 1)
        #expect(rows.first?.reach != nil)
    }

    /// The model tests above call `carryPick` themselves, so the row
    /// that re-keys is held to it here: it carries the pick and
    /// records no removal of its own, which would strand the old key
    /// in a listed profile.
    @Test("the row's re-key carries its reach through carryPick")
    func rekeyWiring() throws {
        let body = try SourceScan.functionBody(
            of: "rekey",
            in: "GestureListRow.swift",
            under: "Settings/Components/Gestures",
            root: "Sources/KiwiDesk"
        )
        #expect(body.contains("model.carryPick(.gesture"))
        #expect(!body.contains("recordRemoval("))
    }
}
