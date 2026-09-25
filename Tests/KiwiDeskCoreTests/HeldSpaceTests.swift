import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Held Spaces (#1507), replaying the owner's desk: a built-in
/// screen and a DELL. `desk` covers both, with Spaces 3 and 4
/// pinned to the DELL; `solo` covers the built-in and declares
/// 1–3, so the DELL's 3 collides and its 4 does not.
@Suite("Held Spaces (#1507)", .serialized)
@MainActor
struct HeldSpaceTests {
    private let builtIn = Display(
        id: DisplayID(1),
        name: "BUILTIN",
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    private let dell = Display(
        id: DisplayID(3),
        name: "DELL",
        frame: CGRect(x: 100, y: 0, width: 200, height: 100)
    )

    private func profile(
        _ name: String,
        screens: [String],
        spaces: [SpaceID],
        pins: [SpaceID: String] = [:]
    ) -> Profile {
        var modes: [SpaceID: LayoutMode] = [:]
        for space in spaces { modes[space] = .bsp }
        return Profile(
            name: name,
            monitorSets: [
                MonitorSet(monitors: screens, spaceMonitorMap: pins)
            ],
            spaces: spaces,
            spaceModes: modes,
            settings: TilingSettings()
        )
    }

    /// Docked on `desk`: window 13 in Space 1, 10 and 11 in the
    /// DELL's 3, 12 in the DELL's 4.
    private func docked() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-1507-\(UUID().uuidString)"
                )
        )
        let dellPin = dell.fingerprint
        try core.profiles.save(
            profile(
                "solo",
                screens: [builtIn.fingerprint],
                spaces: [SpaceID(1), SpaceID(2), SpaceID(3)]
            )
        )
        try core.profiles.save(
            profile(
                "desk",
                screens: [builtIn.fingerprint, dellPin],
                spaces: [SpaceID(1), SpaceID(2), SpaceID(3), SpaceID(4)],
                pins: [SpaceID(3): dellPin, SpaceID(4): dellPin]
            )
        )
        core.handle(.displaysChanged([builtIn, dell]))
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.profiles.currentName == "desk")
        for (id, space) in [(13, 1), (10, 3), (11, 3), (12, 4)] {
            let window = WindowID(UInt32(id))
            core.state.windows.upsert(
                ManagedWindow(id: window, pid: 1, appName: "App\(id)")
            )
            core.state.workspaces.add(window, to: SpaceID(space))
        }
        return core
    }

    private func members(_ core: KiwiCore, _ space: Int) -> [WindowID] {
        core.state.workspaces[SpaceID(space)]?.windows ?? []
    }

    private func ids(_ raw: [Int]) -> [WindowID] {
        raw.map { WindowID(UInt32($0)) }
    }

    @Test("an unplug holds the gone screen's Spaces, renumbering a taken name")
    func unplugHolds() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        #expect(core.profiles.currentName == "solo")
        // The DELL's 3 collides with solo's 3: past solo's last
        // live number (4) it is 5. Its 4 is free and keeps it.
        #expect(
            core.state.heldSpaces[SpaceID(5)]
                == HeldOrigin(
                    name: SpaceID(3),
                    screen: dell.fingerprint,
                    icon: nil
                )
        )
        #expect(core.state.heldSpaces[SpaceID(4)]?.name == SpaceID(4))
        #expect(members(core, 5) == ids([10, 11]))
        #expect(members(core, 4) == ids([12]))
        #expect(members(core, 3).isEmpty)
        #expect(members(core, 1) == ids([13]))
    }

    @Test("a replug sends everything home and the held Spaces retire")
    func replugRefiles() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.handle(.displaysChanged([builtIn, dell]))
        #expect(core.profiles.currentName == "desk")
        #expect(core.state.heldSpaces.isEmpty)
        #expect(core.state.workspaces[SpaceID(5)] == nil)
        #expect(Set(members(core, 3)) == Set(ids([10, 11])))
        #expect(members(core, 4) == ids([12]))
    }

    @Test("a held Space retires when its last window leaves")
    func emptiedRetires() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.state.workspaces.add(WindowID(12), to: SpaceID(1))
        core.retile()
        #expect(core.state.heldSpaces[SpaceID(4)] == nil)
        #expect(core.state.workspaces[SpaceID(4)] == nil)
        #expect(core.state.heldSpaces[SpaceID(5)] != nil)
    }

    @Test("an explicit load ends every hold")
    func explicitLoadEndsHolds() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.execute("load_profile", args: [.string("solo")])
        #expect(core.state.heldSpaces.isEmpty)
        #expect(core.state.workspaces[SpaceID(4)] == nil)
        #expect(core.state.workspaces[SpaceID(5)] == nil)
        #expect(Set(members(core, 1)) == Set(ids([13, 10, 11, 12])))
    }

    @Test("an empty Space of the gone screen is not held")
    func emptySpaceIsNotHeld() throws {
        let core = try docked()
        core.state.workspaces.add(WindowID(12), to: SpaceID(1))
        core.handle(.displaysChanged([builtIn]))
        #expect(core.state.heldSpaces[SpaceID(4)] == nil)
        #expect(core.state.workspaces[SpaceID(4)] == nil)
    }

    @Test("a Desktop-binding switch holds nothing")
    func bindingSwitchDoesNotHold() throws {
        let core = try docked()
        core.state.workspaces.removeDisplay(dell.id)
        core.apply(
            profile: try core.profiles.read(name: "solo"),
            cause: .event
        )
        #expect(core.state.heldSpaces.isEmpty)
        #expect(core.state.workspaces[SpaceID(4)] == nil)
    }

    @Test("Keep and the partitioning record never capture a held Space")
    func captureExcludesHeld() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        let kept = core.buildProfile(name: "kept", modes: nil)
        #expect(!kept.spaces.contains(SpaceID(4)))
        #expect(!kept.spaces.contains(SpaceID(5)))
        core.recordLivePartitioning()
        let record = core.state.profilePartitioning.remembered(for: "solo")
        #expect(record?[SpaceID(4)] == nil)
        #expect(record?[SpaceID(5)] == nil)
    }

    @Test("the bar marks a held Space and says where it came from")
    func barMarksHeld() throws {
        LocalizationManager.shared.select("en")
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        let items = core.spaceBarItems(
            display: builtIn.id,
            style: SpaceBarLook()
        )
        let renumbered = try #require(
            items.first { $0.identity == .space(SpaceID(5)) }
        )
        #expect(
            renumbered.held
                == SpaceBarItemView.Held(
                    screenName: "DELL",
                    originName: SpaceID(3)
                )
        )
        let kept = try #require(
            items.first { $0.identity == .space(SpaceID(4)) }
        )
        #expect(kept.held?.originName == nil)
        let own = try #require(
            items.first { $0.identity == .space(SpaceID(1)) }
        )
        #expect(own.held == nil)
        let view = SpaceBarItemView(frame: .zero)
        view.configure(
            identity: renumbered.identity,
            spaceGlyph: renumbered.spaceGlyph,
            apps: [],
            active: false,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(sticky: "", floating: ""),
            held: renumbered.held
        )
        #expect(!view.heldBadge.isHidden)
        #expect(
            view.accessibilityLabel()
                == "Space 5, held from DELL, where it was Space 3, "
                + "not saved, 0 applications, not current"
        )
    }
}
