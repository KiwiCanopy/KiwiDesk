import Foundation
import Testing

@testable import KiwiDeskCore

/// The slots' storage and resolve (#1873 ruling ▸ Storage): a
/// sparse base over the seeds, a sparse profile override over the
/// base, `null` the tombstone at either level.
@Suite("Trackpad gesture config")
struct TrackpadGestureConfigTests {
    private static let hyper: ScrollChord = [.control, .option]

    @Test("the seeds are the ruled ones, bound and on")
    func seedsAreRuled() {
        let seeds = TrackpadGestureSeeds.resolved(
            base: TrackpadGestureMap(),
            profile: nil
        )
        #expect(seeds[.rotate]?.action == "KiwiDesk.cycle_mode()")
        #expect(seeds[.rotate]?.modifiers == Self.hyper)
        #expect(seeds[.spread]?.action == "KiwiDesk.toggle_maximized()")
        #expect(seeds[.spread]?.modifiers == Self.hyper)
        #expect(seeds[.tap4]?.action == KiwiHubSide.shortcuts.lua)
        #expect(seeds[.tap4]?.modifiers == [])
        // The tap toggles, since a single gesture has no Forward
        // (#3206).
        #expect(seeds[.tap3]?.action == "KiwiDesk.focus_space_last()")
        #expect(seeds[.swipe3] == nil)
        // Each seed runs the Shortcuts catalogue's own Lua
        // (`TrackpadSeedCatalogueTests` in the GUI target).
        // Every seed passes its own slot's refusals.
        for (slot, binding) in TrackpadGestureSeeds.seeds {
            #expect(binding.refusal(on: slot) == nil, "\(slot)")
        }
    }

    @Test("a base tombstone unbinds a seed; a profile re-binds it")
    func layersResolveInOrder() {
        let swipe = TrackpadGestureBinding(
            action: "focus",
            modifiers: Self.hyper
        )
        let base = TrackpadGestureMap([
            .tap3: .unbound, .swipe3: .bound(swipe),
        ])
        let profile = TrackpadGestureMap([
            .tap3: .bound(.init(action: "KiwiDesk.cycle_mode()")),
            .swipe3: .unbound,
        ])
        let baseOnly = TrackpadGestureSeeds.resolved(
            base: base,
            profile: nil
        )
        #expect(baseOnly[.tap3] == nil)
        #expect(baseOnly[.swipe3] == swipe)
        #expect(baseOnly[.tap4] != nil, "an untouched seed stays")
        let both = TrackpadGestureSeeds.resolved(
            base: base,
            profile: profile
        )
        #expect(both[.tap3]?.action == "KiwiDesk.cycle_mode()")
        #expect(both[.swipe3] == nil)
    }

    @Test("an untouched tap3 follows the seed; a stored one wins")
    func tap3FollowsTheSeed() {
        let untouched = TrackpadGestureSeeds.resolved(
            base: TrackpadGestureMap(),
            profile: nil
        )
        #expect(untouched[.tap3]?.action == "KiwiDesk.focus_space_last()")
        let back = TrackpadGestureBinding(
            action: "KiwiDesk.focus_space_back()"
        )
        let stored = TrackpadGestureSeeds.resolved(
            base: TrackpadGestureMap([.tap3: .bound(back)]),
            profile: nil
        )
        #expect(stored[.tap3] == back)
    }

    @Test("a refused binding a hand edit reached is dropped")
    func refusedBindingsDrop() {
        let base = TrackpadGestureMap([
            .swipe4: .bound(.init(action: "focus")),
            .swipe5: .bound(.init(action: "fly", modifiers: Self.hyper)),
            .rotate: .bound(.init(action: "x()")),
            .tap5: .bound(.init(action: "  ")),
        ])
        let resolved = TrackpadGestureSeeds.resolved(
            base: base,
            profile: nil
        )
        for slot in [TrackpadGestureSlot.swipe4, .swipe5, .rotate, .tap5] {
            #expect(resolved[slot] == nil, "\(slot)")
        }
    }

    @Test("the wire shape round-trips, null and all")
    func roundTrips() throws {
        let map = TrackpadGestureMap([
            .tap3: .unbound,
            .swipe4: .bound(.init(action: "swap", modifiers: Self.hyper)),
            .tap5: .bound(.init(action: "x()")),
        ])
        let data = try JSONEncoder().encode(map)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(object["tap3"] is NSNull)
        let swipe = try #require(object["swipe4"] as? [String: String])
        #expect(swipe == ["family": "swap", "modifiers": "control+option"])
        let tap = try #require(object["tap5"] as? [String: String])
        #expect(tap == ["lua": "x()", "modifiers": ""])
        #expect(object.count == 3)
        let back = try JSONDecoder().decode(
            TrackpadGestureMap.self,
            from: data
        )
        #expect(back == map)
    }

    @Test("a slot's action under the other slot kind's key fails")
    func wrongKeyFails() {
        for json in [
            #"{"swipe3": {"lua": "focus", "modifiers": "control"}}"#,
            #"{"tap3": {"family": "x()"}}"#,
        ] {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(
                    TrackpadGestureMap.self,
                    from: Data(json.utf8)
                )
            }
        }
    }

    @Test("an unknown slot fails the decode")
    func unknownSlotFails() {
        let data = Data(#"{"tap9": null}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TrackpadGestureMap.self, from: data)
        }
    }

    @Test("gui.json and a profile carry the map under trackpad_gesture")
    func storesCarryTheMap() throws {
        var config = GuiConfig()
        let empty =
            try JSONSerialization.jsonObject(
                with: JSONEncoder().encode(config)
            ) as? [String: Any]
        #expect(empty?["trackpad_gesture"] == nil, "sparse when empty")
        config.trackpadGesture = TrackpadGestureMap([.tap4: .unbound])
        let data = try JSONEncoder().encode(config)
        let object =
            try JSONSerialization.jsonObject(with: data)
            as? [String: Any]
        #expect(object?["trackpad_gesture"] != nil)
        let back = try JSONDecoder().decode(GuiConfig.self, from: data)
        #expect(back.trackpadGesture == config.trackpadGesture)

        var profile = Profile(
            name: "P",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings()
        )
        profile.trackpadGesture = TrackpadGestureMap([
            .tap3: .bound(.init(action: "KiwiDesk.cycle_mode()"))
        ])
        let profileData = try JSONEncoder().encode(profile)
        let profileObject =
            try JSONSerialization.jsonObject(
                with: profileData
            ) as? [String: Any]
        #expect(profileObject?["trackpad_gesture"] != nil)
        let decoded = try JSONDecoder().decode(
            Profile.self,
            from: profileData
        )
        #expect(decoded.trackpadGesture == profile.trackpadGesture)
    }
}
