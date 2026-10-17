import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Layouts to cycle row (#453), draft to files: the loaded page
/// shows its profile's own list, gui.json keeps the shared one, a
/// tick writes a profile's file, a Revert drops the edit, and every
/// edit keeps the list a cycle the decoder accepts.
@Suite("Layout cycle row, draft to files (#453)", .serialized)
@MainActor
struct LayoutCycleModelTests {
    private let key = RuleReachTable<[LayoutMode]>.modeCycleKey

    /// Work (loaded) cycles Stack › Monocle; Home is stored and
    /// follows the base.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.modeCycle = [.stack, .monocle]
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

    @Test("the loaded page shows its own list; gui.json keeps the base")
    func loadedPageIsOwn() throws {
        let model = try makeModel()
        #expect(model.config.modeCycle == [.stack, .monocle])
        let row = try #require(model.cycleReach())
        #expect(!row.shared && row.users == ["Work"])
        #expect(model.sidecarConfig.modeCycle == ModeCycle.defaultList)
    }

    /// The row reads the draft's pick back before any Save (#2342).
    /// A tick on a shared row is a JOIN the table cannot show until
    /// the Save makes it, so only the pick can say Home was ticked:
    /// Work follows the shared cycle here, Home keeps its own.
    @Test("a tick shows in the row before the Save")
    func tickReadsBack() throws {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        var home = profile("Home")
        home.modeCycle = [.grid, .bsp]
        try core.profiles.write(home)
        let model = makeTestModel(core: core)
        model.reload()
        let before = try #require(model.cycleReach())
        #expect(before.shared && before.joined.isEmpty)
        model.setProfile(.cycle, key, "Home", true)
        let row = try #require(model.cycleReach())
        #expect(row.joined == ["Home"])
    }

    @Test("ticking Home writes Work's list into Home's file")
    func tickHome() throws {
        let model = try makeModel()
        model.setProfile(.cycle, key, "Home", true)
        model.updateActiveProfile()
        #expect(
            try model.core.profiles.read(name: "Home").modeCycle
                == [.stack, .monocle]
        )
        #expect(
            model.core.guiConfigStore.load()?.modeCycle
                == ModeCycle.defaultList
        )
    }

    @Test("an edit lights the draft and a dropped rule half drops it")
    func editIsDrafted() throws {
        let model = try makeModel()
        #expect(!model.isDirty)
        model.addCycleMode(.grid)
        #expect(model.config.modeCycle == [.stack, .monocle, .grid])
        #expect(model.isDirty)
        model.dropRuleHalf()
        #expect(model.config.modeCycle == [.stack, .monocle])
    }

    @Test("edits keep a cycle: never below two, each layout once")
    func editsStayValid() {
        let model = makeTestModel()
        model.config.modeCycle = [.bsp, .scrolling]
        #expect(!model.modeCycleCanRemove)
        model.removeCycleMode(.bsp)
        #expect(model.config.modeCycle == [.bsp, .scrolling])
        model.addCycleMode(.bsp)
        #expect(model.config.modeCycle == [.bsp, .scrolling])
        model.addCycleMode(.grid)
        #expect(model.modeCycleCanRemove)
        model.removeCycleMode(.bsp)
        #expect(model.config.modeCycle == [.scrolling, .grid])
        #expect(!model.modeCycleAddable.contains(.grid))
        #expect(model.modeCycleAddable.contains(.bsp))
    }

    @Test("Move Up and Down swap neighbours and stop at the ends")
    func stepsStopAtTheEnds() {
        let model = makeTestModel()
        model.config.modeCycle = [.bsp, .scrolling, .floating]
        model.stepCycleMode(.bsp, by: -1)
        #expect(model.config.modeCycle == [.bsp, .scrolling, .floating])
        model.stepCycleMode(.floating, by: -1)
        #expect(model.config.modeCycle == [.bsp, .floating, .scrolling])
        model.stepCycleMode(.scrolling, by: 1)
        #expect(model.config.modeCycle == [.bsp, .floating, .scrolling])
    }

    @Test("a drag commits only a reorder of the same layouts")
    func dragCommitsAReorder() {
        let model = makeTestModel()
        model.config.modeCycle = [.bsp, .scrolling, .floating]
        model.reorderCycle([.floating, .bsp, .scrolling])
        #expect(model.config.modeCycle == [.floating, .bsp, .scrolling])
        model.reorderCycle([.floating, .bsp])
        #expect(model.config.modeCycle == [.floating, .bsp, .scrolling])
    }

    @Test("the readout lists the cycle in order")
    func readoutIsOrdered() {
        LocalizationManager.shared.select("en")
        #expect(
            LayoutCycleWords.readout([.bsp, .scrolling, .floating])
                == "BSP › Scrolling › Floating"
        )
    }

    @Test("a translated readout keeps the spaces around its mark")
    func translatedReadoutKeepsSpaces() {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select("en") }
        let text = LayoutCycleWords.readout([.bsp, .stack])
        #expect(text.contains(" › "), "\(text)")
    }
}
