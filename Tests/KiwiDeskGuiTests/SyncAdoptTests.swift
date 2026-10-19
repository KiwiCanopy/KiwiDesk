import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A change another Mac made, entering the Settings draft (#2324
/// ruling 4): a clean draft re-reads; a draft with edits takes the
/// other Mac's changes to the settings it did not edit and keeps
/// its own, with a strip saying so; a setting both changed is one
/// question at Save. Main-actor cost: one test core and model per
/// test, no scans.
@Suite("A synced change enters the draft", .serialized)
@MainActor
struct SyncAdoptTests {
    private let change = SyncedChange(paths: ["gui.json"], mac: "Studio")

    private func setup() throws -> (KiwiCore, SettingsModel) {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-sync-adopt-\(UUID())")
        )
        core.onLog = { _ in }
        try core.guiConfigStore.save(GuiConfig())
        core.loadConfig()
        let model = makeTestModel(core: core)
        model.reload()
        return (core, model)
    }

    /// The other Mac's write: `edit` applied to the stored file.
    private func theirs(
        _ core: KiwiCore,
        _ edit: (inout GuiConfig) -> Void
    ) throws {
        var stored = try #require(core.guiConfigStore.load())
        edit(&stored)
        try core.guiConfigStore.save(stored)
        core.loadConfig()
    }

    @Test("A clean draft takes the change and shows no strip")
    func cleanDraftReloads() throws {
        let (core, model) = try setup()
        try theirs(core) { $0.spaceHistory = .allScreens }
        model.adoptSyncedChange(change)
        #expect(model.config.spaceHistory == .allScreens)
        #expect(!model.isDirty)
        #expect(model.sync.arrived == nil)
    }

    @Test("Edits to another setting stay, theirs is taken, a strip")
    func otherSettingMerges() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .bsp]
        #expect(model.isDirty)
        try theirs(core) { $0.spaceHistory = .allScreens }
        model.adoptSyncedChange(change)
        #expect(model.config.spaceHistory == .allScreens)
        #expect(model.cleanConfig.spaceHistory == .allScreens)
        #expect(model.config.modeCycle == [.stack, .bsp])
        #expect(model.sync.arrived == change)
        #expect(model.sync.conflicts.isEmpty)
    }

    @Test("A setting both changed is asked about once, at Save")
    func sameSettingAsks() throws {
        let (core, model) = try setup()
        model.config.spaceHistory = .allScreens
        try theirs(core) {
            $0.spaceHistory = .allScreens
            $0.modeCycle = [.monocle, .bsp]
        }
        // Equal values are no conflict: only modeCycle moved there.
        model.adoptSyncedChange(change)
        #expect(model.sync.conflicts.isEmpty)

        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.config.modeCycle == [.stack, .monocle])
        #expect(model.sync.conflicts.map(\.key) == [.shortcuts(.modeCycle)])
        #expect(model.sync.conflicts.first?.mac == "Studio")
        // Named as the setting, never as one of its readout rows.
        #expect(
            model.sync.conflicts.first?.label
                == SettingsValueReadout.label(for: .shortcuts(.modeCycle))
        )

        model.performPrimarySave()
        #expect(model.sync.question?.key == .shortcuts(.modeCycle))
        #expect(model.config.modeCycle == [.stack, .monocle])
    }

    @Test("Use Theirs takes the other Mac's value back")
    func useTheirsTakesIt() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.askNextSyncConflict())
        model.answerSyncConflict(useTheirs: true)
        #expect(model.config.modeCycle == [.bsp, .stack])
        #expect(model.sync.conflicts.isEmpty)
        #expect(model.sync.question == nil)
    }

    @Test("Keep Yours keeps the draft's value")
    func keepYoursKeepsIt() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        #expect(model.askNextSyncConflict())
        model.answerSyncConflict(useTheirs: false)
        #expect(model.config.modeCycle == [.stack, .monocle])
        #expect(model.sync.conflicts.isEmpty)
    }

    @Test("A setting reverted since is no longer a question")
    func revertedIsNoQuestion() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        model.config.modeCycle = model.cleanConfig.modeCycle
        #expect(!model.askNextSyncConflict())
    }

    @Test("A second arrival keeps the first arrival's question")
    func questionsSurviveASecondArrival() throws {
        let (core, model) = try setup()
        model.config.modeCycle = [.stack, .monocle]
        try theirs(core) { $0.modeCycle = [.bsp, .stack] }
        model.adoptSyncedChange(change)
        try theirs(core) { $0.spaceHistory = .allScreens }
        model.adoptSyncedChange(change)
        #expect(model.sync.conflicts.map(\.key) == [.shortcuts(.modeCycle)])
        #expect(model.config.spaceHistory == .allScreens)
    }

    @Test("init.lua's question survives a gui.json-only arrival")
    func luaQuestionSurvives() throws {
        let (core, model) = try setup()
        model.luaSource = "-- mine\n"
        try "-- theirs\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        model.adoptSyncedChange(SyncedChange(paths: ["init.lua"], mac: nil))
        try theirs(core) { $0.spaceHistory = .allScreens }
        model.adoptSyncedChange(change)
        #expect(model.sync.conflicts.contains { $0.key == nil })
        #expect(model.luaSource == "-- mine\n")
    }

    /// The Space Bar's edge and its per-screen map revert as one
    /// pair: the draft's edge laid back over the other Mac's map
    /// is asked about, once, as the edge.
    @Test("A pair writer laid over the other Mac's change asks once")
    func pairWriterAsks() throws {
        let (core, model) = try setup()
        model.config.settings.spaceBarStyle.edge = .bottom
        core.tiler.settings.spaceBarStyle.edgeOverride = ["S": .left]
        model.adoptSyncedChange(change)
        // One question for the pair, whichever key the census books
        // the edit to.
        #expect(
            model.sync.conflicts.count == 1,
            "\(model.sync.conflicts.map(\.id))"
        )
        let question = try #require(model.sync.conflicts.first)
        #expect(!question.yours.isEmpty)
        #expect(!question.theirs.isEmpty)
        #expect(model.config.settings.spaceBarStyle.edge == .bottom)
    }

    @Test("init.lua edited on both Macs is one question")
    func luaIsOneQuestion() throws {
        let (core, model) = try setup()
        model.luaSource = "-- mine\n"
        try "-- theirs\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        model.adoptSyncedChange(
            SyncedChange(paths: ["init.lua"], mac: nil)
        )
        #expect(model.luaSource == "-- mine\n")
        #expect(model.sync.conflicts.count == 1)
        #expect(model.sync.conflicts.first?.key == nil)
        #expect(model.askNextSyncConflict())
        model.answerSyncConflict(useTheirs: true)
        #expect(model.luaSource == "-- theirs\n")
    }
}
