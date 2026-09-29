import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Scroll-gesture rows' checklist, draft to files (#1656): each
/// value reaches all profiles (gui.json's base) or a chosen set
/// (their sparse overrides), through the same Save as shortcuts.
@Suite("Rule reach, scroll gesture rows (#1656)", .serialized)
@MainActor
struct ScrollGestureReachModelTests {
    private let natural = ScrollGestureField.naturalMouse.rawValue
    private let pan = ScrollGestureField.pan.rawValue

    /// Work (loaded) turns Natural scrolling off for the mouse;
    /// Home is stored and follows the base.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.scrollGesture = ScrollGestureOverride(naturalMouse: false)
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

    @Test("the loaded page shows its own value, listed as its own")
    func ownValueIsListed() throws {
        let model = try makeModel()
        #expect(model.config.scrollGesture.naturalMouse == false)
        let row = try #require(model.scrollReach(natural))
        #expect(!row.shared && row.users == ["Work"])
        #expect(try #require(model.scrollReach(pan)).shared)
        // gui.json keeps the shared value, whatever the page shows.
        #expect(model.sidecarConfig.scrollGesture == .defaults)
    }

    @Test("a shared edit writes gui.json and leaves the profiles")
    func sharedEditWritesTheBase() throws {
        let model = try makeModel()
        model.config.scrollGesture.pan = [.command, .option]
        #expect(model.globalsChanged)
        model.updateActiveProfile()
        let core = model.core
        #expect(
            core.guiConfigStore.load()?.scrollGesture.pan
                == [.command, .option]
        )
        #expect(
            try core.profiles.read(name: "Work").scrollGesture
                == ScrollGestureOverride(naturalMouse: false)
        )
        #expect(try core.profiles.read(name: "Home").scrollGesture == nil)
    }

    @Test("ticking Home writes Work's own value into Home's file")
    func tickHome() throws {
        let model = try makeModel()
        model.setProfile(.scroll, natural, "Home", true)
        model.updateActiveProfile()
        #expect(
            try model.core.profiles.read(name: "Home").scrollGesture
                == ScrollGestureOverride(naturalMouse: false)
        )
        #expect(model.core.guiConfigStore.load()?.scrollGesture == .defaults)
    }
}
