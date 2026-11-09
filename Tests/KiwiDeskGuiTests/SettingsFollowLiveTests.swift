import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An open Settings window follows live (#3098): a live change
/// re-seeds every draft leaf the user has not edited, keeps an
/// edited one, and the controls and the pill read one moment.
@Suite("Settings follows live (#3098)", .serialized)
@MainActor
struct SettingsFollowLiveTests {
    /// A loaded profile on one laptop-shaped screen, and a clean
    /// live draft over it.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-live-\(UUID().uuidString)")
        )
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 160, height: 100)
            )
        )
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(
            Profile(
                name: "Desk",
                monitorSets: [MonitorSet(monitors: ["A:160x100"])],
                spaces: ["1"],
                spaceModes: [:],
                settings: core.tiler.settings
            )
        )
        #expect(
            core.execute("load_profile", args: [.string("Desk")])
                .isSuccess
        )
        let model = makeTestModel(core: core)
        model.reload()
        #expect(!model.isDirty)
        return model
    }

    private func setLaptopHeight(_ model: SettingsModel, _ share: Double) {
        let reply = model.core.execute(
            "maximize.set_share",
            args: [.string("height"), .number(share), .string("laptop")]
        )
        #expect(reply.isSuccess)
    }

    private var laptopHeight: WritableKeyPath<GuiConfig, Double> {
        \.settings.maximize.heightShare[.laptop]
    }

    /// The control binds `config.settings.maximize.heightShare`.
    @Test("an untouched leaf takes the live value")
    func untouchedLeafFollows() throws {
        let model = try makeModel()
        setLaptopHeight(model, 0.4)
        model.liveSettingsMoved()
        #expect(model.config[keyPath: laptopHeight] == 0.4)
        #expect(!model.isDirty)
        // The pill lists the same value, as a live row.
        let row = try #require(
            SettingsDiffRowSource.rows(for: model)
                .first { $0.key == .behaviour(.maximizeHeightShare) }
        )
        #expect(row.section == .live)
        #expect(model.liveUnsaved)
    }

    @Test("an edited leaf keeps the user's value")
    func editedLeafStays() throws {
        let model = try makeModel()
        model.config[keyPath: laptopHeight] = 0.6
        #expect(model.isDirty)
        setLaptopHeight(model, 0.4)
        model.liveSettingsMoved()
        #expect(model.config[keyPath: laptopHeight] == 0.6)
        #expect(model.isDirty)
        // The draft's row narrates it, from live to the edit.
        let rows = SettingsDiffRowSource.rows(for: model)
            .filter { $0.key == .behaviour(.maximizeHeightShare) }
        #expect(rows.map(\.section) == [.draft])
        #expect(model.draftChangeCount == 1)
    }

    /// One leaf edited, a sibling changed live: each keeps its own.
    @Test("an edit beside a live change keeps both")
    func editBesideLiveChange() throws {
        let model = try makeModel()
        model.config.settings.maximize.widthShare[.laptop] = 0.6
        setLaptopHeight(model, 0.4)
        model.liveSettingsMoved()
        #expect(model.config[keyPath: laptopHeight] == 0.4)
        #expect(model.config.settings.maximize.widthShare[.laptop] == 0.6)
        #expect(model.draftChangeCount == 1)
        model.updateActiveProfile()
        let stored = try model.core.resolvedSettings(
            of: model.core.profiles.read(name: "Desk")
        )
        #expect(stored.maximize.heightShare[.laptop] == 0.4)
        #expect(stored.maximize.widthShare[.laptop] == 0.6)
    }

    @Test("a stored profile's draft stays as it is")
    func storedProfileStays() throws {
        let model = try makeModel()
        // The guard alone: the draft drawn is another file's.
        model.target = .storedProfile("Other")
        let before = model.config[keyPath: laptopHeight]
        setLaptopHeight(model, 0.4)
        model.liveSettingsMoved()
        #expect(model.config[keyPath: laptopHeight] == before)
    }

    /// A change made while the window was away arrives at its
    /// window-key return, through the same door.
    @Test("a window-key return follows what moved while away")
    func returnFollows() throws {
        let model = try makeModel()
        setLaptopHeight(model, 0.4)
        model.refreshOwner()
        #expect(model.config[keyPath: laptopHeight] == 0.4)
        #expect(model.liveUnsaved)
    }

    /// A row's ↺ moves live itself: the control is back at once,
    /// not a turn later through the hook.
    @Test("a live row's revert puts the control back at once")
    func revertFollowsAtOnce() throws {
        let model = try makeModel()
        let saved = model.config[keyPath: laptopHeight]
        model.config.settings.maximize.widthShare[.laptop] = 0.6
        setLaptopHeight(model, 0.4)
        model.liveSettingsMoved()
        let row = try #require(
            SettingsDiffRowSource.rows(for: model)
                .first { $0.key == .behaviour(.maximizeHeightShare) }
        )
        model.revertLive(row.keepIDs)
        #expect(model.config[keyPath: laptopHeight] == saved)
        #expect(model.config.settings.maximize.widthShare[.laptop] == 0.6)
    }

    @Test("a stale page stays as it is")
    func stalePageStays() throws {
        let model = try makeModel()
        model.reachPage = "Gone"
        #expect(model.draftStale)
        let before = model.config[keyPath: laptopHeight]
        setLaptopHeight(model, 0.4)
        model.liveSettingsMoved()
        #expect(model.config[keyPath: laptopHeight] == before)
    }

    /// Sync's baseline holds the other Mac's value while a question
    /// is open (#2450), so live may not overwrite it.
    @Test("an open sync question holds the draft")
    func syncQuestionHolds() throws {
        let model = try makeModel()
        model.sync.conflicts = [
            SyncConflict(
                key: nil,
                label: "",
                yours: "",
                theirs: "",
                mac: nil
            )
        ]
        let before = model.config[keyPath: laptopHeight]
        setLaptopHeight(model, 0.4)
        model.liveSettingsMoved()
        #expect(model.config[keyPath: laptopHeight] == before)
    }
}
