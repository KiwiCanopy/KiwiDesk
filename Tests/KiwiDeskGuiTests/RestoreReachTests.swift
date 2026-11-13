import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Restore Defaults asks before it changes another profile (#3248):
/// "here" writes the edited profile alone, "every profile" resets the
/// seeded rows of all, whatever value each held, and rows the user
/// added stay in both. Work is loaded; Home and Travel are stored.
@Suite("Restore Defaults reaches as far as asked (#3248)", .serialized)
@MainActor
struct RestoreReachTests {
    private let lua = LuaAction(lua: "KiwiDesk.reload_config()", kind: .custom)
    private let other = LuaAction(
        lua: "KiwiDesk.focus(\"left\")",
        kind: .custom
    )
    private let added = GestureKey(.rightClick, [.control, .option])

    /// A seeded mouse gesture: the one each case moves off its seed.
    private var seeded: GestureKey {
        get throws {
            try #require(
                GestureSeeds.seeds.keys.sorted().first {
                    $0.input.device == .mouse
                }
            )
        }
    }

    /// A second seeded mouse gesture, which Home changes and Work
    /// keeps: only "every profile" reaches it.
    private var second: GestureKey {
        get throws {
            try #require(
                GestureSeeds.seeds.keys.sorted().filter {
                    $0.input.device == .mouse
                }.dropFirst().first
            )
        }
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

    /// The issue's case: Work and Home bind the seed to one action,
    /// Travel to another; Work also added a row of its own. With
    /// `travelAdds`, Travel only adds a row and keeps the seed.
    private func gestureModel(
        base: GestureMap = GestureMap(),
        travelAdds: Bool = false
    ) throws -> SettingsModel {
        let key = try seeded
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.gesture = base
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.gesture = GestureMap([
            key: .bound(.run(lua)), added: .bound(.run(other)),
        ])
        try core.profiles.save(work)
        var home = profile("Home")
        let other2 = try second
        home.gesture = GestureMap([
            key: .bound(.run(lua)), other2: .bound(.run(other)),
        ])
        try core.profiles.write(home)
        var travel = profile("Travel")
        travel.gesture = GestureMap(
            travelAdds
                ? [added: .bound(.run(lua))] : [key: .bound(.run(other))]
        )
        try core.profiles.write(travel)
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func gesture(_ model: SettingsModel, _ name: String) throws
        -> GestureMap?
    {
        try model.core.profiles.read(name: name).gesture
    }

    @Test("who changed is the union across the card's seeded gestures")
    func whoChanged() throws {
        let model = try gestureModel()
        #expect(
            model.gestureRestoreChangedElsewhere(on: .mouse)
                == ["Home", "Travel"]
        )
        // A profile that only added a row has changed no seed.
        let adds = try gestureModel(travelAdds: true)
        #expect(adds.gestureRestoreChangedElsewhere(on: .mouse) == ["Home"])
    }

    /// Nobody else changed the seed: the restore is the edited
    /// profile's alone and stages no reach, so the draft's reach is
    /// what it was (Save as new stays open).
    @Test("a restore nobody else shares stages no reach")
    func unsharedRestoreStagesNothing() throws {
        let model = try gestureModel(travelAdds: true)
        try model.core.profiles.write(profile("Home"))
        model.reload()
        #expect(model.gestureRestoreChangedElsewhere(on: .mouse) == [])
        model.restoreGestureDefaults(on: .mouse, reach: .here)
        #expect(model.reachEdits.isEmpty)
    }

    @Test("here resets Work alone; Home and Travel keep theirs")
    func gestureHere() throws {
        let key = try seeded
        let model = try gestureModel()
        model.restoreGestureDefaults(on: .mouse, reach: .here)
        model.updateActiveProfile()
        let work = try gesture(model, "Work")
        #expect(work?[key] == nil)
        #expect(work?[added] == .bound(.run(other)))
        #expect(try gesture(model, "Home")?[key] == .bound(.run(lua)))
        #expect(
            try gesture(model, "Home")?[try second] == .bound(.run(other))
        )
        #expect(try gesture(model, "Travel")?[key] == .bound(.run(other)))
        #expect(model.core.guiConfigStore.load()?.gesture[key] == nil)
    }

    @Test("every profile resets every value, matching or not")
    func gestureEveryProfile() throws {
        let key = try seeded
        let model = try gestureModel()
        model.restoreGestureDefaults(on: .mouse, reach: .everyProfile)
        model.updateActiveProfile()
        for name in ["Work", "Home", "Travel"] {
            #expect(try gesture(model, name)?[key] == nil, "\(name)")
        }
        // A seed Work never moved is reset where Home changed it.
        #expect(try gesture(model, "Home")?[try second] == nil)
        #expect(try gesture(model, "Work")?[added] == .bound(.run(other)))
        #expect(model.core.guiConfigStore.load()?.gesture[key] == nil)
    }

    /// A shared base off the seed: the followers count as changed,
    /// and "here" leaves the base and them alone.
    @Test("here never moves a shared base the others follow")
    func gestureHereKeepsTheBase() throws {
        let key = try seeded
        let model = try gestureModel(
            base: GestureMap([key: .bound(.run(other))])
        )
        model.restoreGestureDefaults(on: .mouse, reach: .here)
        model.updateActiveProfile()
        #expect(
            model.core.guiConfigStore.load()?.gesture[key]
                == .bound(.run(other))
        )
        let work = try #require(model.gestureReach(key.spelling))
        #expect(work.users == ["Work"])
        #expect(try gesture(model, "Home")?[key] == .bound(.run(lua)))
    }

    @Test("who else changed reads by name, then as a count")
    func changedInLadder() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            RestoreReachWords.changedIn(["Home", "Travel"])
                == "Changed in Home, Travel."
        )
        #expect(
            RestoreReachWords.changedIn(["A", "B", "C"])
                == "Changed in profiles: 3"
        )
    }
}
