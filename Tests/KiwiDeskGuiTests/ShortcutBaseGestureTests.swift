import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The "Shortcuts use" switch over the gesture rows (#3444): the
/// seeds follow the base, a stored row and a profile's override
/// move with the shared map, the moved rows read as the switch's
/// one row, and a row the switch could not move is listed.
@Suite("Shortcut base switch over gestures (#3444)", .serialized)
@MainActor
struct ShortcutBaseGestureTests {
    private let pan: ScrollChord = [.control, .option]
    private let hyper: ScrollChord = [.hyper]

    /// Work is loaded and edited; Home follows the shared map with
    /// `home` as its own override.
    private func model(
        base: GestureMap = GestureMap(),
        home: GestureMap? = nil
    ) throws -> (SettingsModel, KiwiCore) {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.gesture = base
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work", nil))
        try core.profiles.write(profile("Home", home))
        let model = makeTestModel(core: core)
        model.reload()
        return (model, core)
    }

    private func profile(_ name: String, _ gesture: GestureMap?) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings(),
            gesture: gesture
        )
    }

    @Test("the seeds follow the switch and the pill reads one row")
    func seedsFollow() throws {
        LocalizationManager.shared.select("en")
        let (model, _) = try model()
        model.setShortcutBase(.hyper)
        #expect(model.config.gesture.isEmpty)
        let page = GestureListEdits.rows(
            in: model.config.gesture,
            on: .mouse,
            shortcutBase: model.config.shortcutBase
        )
        #expect(page.contains(GestureKey(.drag, hyper)))
        #expect(!page.contains(GestureKey(.drag, pan)))
        let rows = SettingsDiffRowSource.rows(for: model)
        #expect(!rows.contains { $0.key == .shortcuts(.gestureBindings) })
        #expect(model.gestureRowsLeftOnStandard.isEmpty)
    }

    @Test("a profile's tombstone moves with the shared map on Save")
    func profileFollowsOnSave() throws {
        var home = GestureMap()
        home[GestureKey(.drag, pan)] = .unbound
        let (model, core) = try model(home: home)
        model.setShortcutBase(.hyper)
        let reach = try #require(model.encodedReach)
        #expect(
            reach.gestures.resolved(for: "Home")[
                GestureKey(.drag, hyper).spelling
            ] == nil
        )
        model.updateActiveProfile()
        #expect(core.guiConfigStore.load()?.shortcutBase == .hyper)
        let stored = try core.profiles.read(name: "Home")
        #expect(stored.gesture?[GestureKey(.drag, hyper)] == .unbound)
        #expect(stored.gesture?[GestureKey(.drag, pan)] == nil)
    }

    @Test("a seed whose ✦ key a row holds stays and is listed")
    func heldSeedIsListed() throws {
        var base = GestureMap()
        base[GestureKey(.drag, hyper)] = .bound(.grab(.resize))
        let (model, _) = try model(base: base)
        model.setShortcutBase(.hyper)
        #expect(
            model.config.gesture[GestureKey(.drag, pan)]
                == .bound(.grab(.move))
        )
        let left = model.gestureRowsLeftOnStandard
        #expect(
            left.map(\.reason) == [
                .taken(target: GestureKey(.drag, hyper), by: .grab(.resize))
            ]
        )
    }

    @Test("another profile's own ⌃⌥ row is listed")
    func otherProfileRowIsListed() throws {
        var home = GestureMap()
        home[GestureKey(.wheel, pan.union(.shift))] = .bound(.family(.walk))
        let (model, _) = try model(home: home)
        model.setShortcutBase(.hyper)
        #expect(
            model.gestureRowsLeftOnStandard.map(\.reason) == [
                .profile("Home")
            ]
        )
    }

    @Test("↺ on the switch puts the gesture map back whole")
    func revertRestores() throws {
        var base = GestureMap()
        base[GestureKey(.drag, hyper)] = .bound(.grab(.resize))
        let (model, _) = try model(base: base)
        model.setShortcutBase(.hyper)
        #expect(model.config.gesture != base)
        let row = try #require(
            SettingsDiffRowSource.rows(for: model).first {
                $0.key == .shortcuts(.shortcutBase)
            }
        )
        model.revert(row)
        #expect(model.config.shortcutBase == .standard)
        #expect(model.config.gesture == base)
    }
}
