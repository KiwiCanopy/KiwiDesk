import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Space history row (#1655), draft to files: the loaded page
/// shows its profile's own kind, gui.json keeps the shared one, a
/// shared edit writes the base, a tick writes a profile's file, and
/// the row greys only on a stored profile saved for one screen.
@Suite("Space history row, draft to files (#1655)", .serialized)
@MainActor
struct SpaceHistoryReachModelTests {
    private let key = RuleReachTable<SpaceHistoryKind>.spaceHistoryKey

    /// Work (loaded) walks all screens; Home is stored and follows
    /// the base.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.spaceHistory = .allScreens
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

    private func summary(_ name: String, count: Int) -> ProfileSummary {
        ProfileSummary(
            name: name,
            count: count,
            sets: [],
            isDefault: false,
            matchesLive: false,
            matchesConnectedCount: false,
            spaceCount: 0,
            shortcutOverrideCount: 0
        )
    }

    @Test("the loaded page shows its own kind; gui.json keeps the base")
    func loadedPageIsOwn() throws {
        let model = try makeModel()
        #expect(model.config.spaceHistory == .allScreens)
        let row = try #require(model.historyReach())
        #expect(!row.shared && row.users == ["Work"])
        #expect(model.sidecarConfig.spaceHistory == .perScreen)
    }

    @Test("ticking Home writes Work's kind into Home's file")
    func tickHome() throws {
        let model = try makeModel()
        model.setProfile(.history, key, "Home", true)
        model.updateActiveProfile()
        #expect(
            try model.core.profiles.read(name: "Home").spaceHistory
                == .allScreens
        )
        #expect(model.core.guiConfigStore.load()?.spaceHistory == .perScreen)
    }

    @Test("the row greys only on a stored one-screen profile")
    func greysOnOneScreen() {
        let model = makeTestModel()
        model.profileSummaries = [
            summary("Laptop", count: 1), summary("Desk", count: 2),
        ]
        #expect(!model.spaceHistoryRunsOnOneScreen)
        model.target = .storedProfile("Laptop")
        #expect(model.spaceHistoryRunsOnOneScreen)
        model.target = .storedProfile("Desk")
        #expect(!model.spaceHistoryRunsOnOneScreen)
    }
}
