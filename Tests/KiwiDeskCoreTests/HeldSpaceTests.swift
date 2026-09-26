import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Held Spaces (#1507), replaying the owner's desk: a built-in
/// screen and a DELL. `desk` covers both, with Spaces 3 and 4
/// pinned to the DELL; `solo` covers the built-in and declares
/// 1–3, so the DELL's 3 collides and its 4 does not — and takes
/// the number after the 3's, keeping the order (#1664).
@Suite("Held Spaces (#1507)", .serialized)
@MainActor
struct HeldSpaceTests {
    private let desk = HeldSpaceDesk()
    private var builtIn: Display { desk.builtIn }
    private var dell: Display { desk.dell }

    private func docked() throws -> KiwiCore { try desk.docked() }

    private func members(_ core: KiwiCore, _ space: Int) -> [WindowID] {
        desk.members(core, space)
    }

    private func ids(_ raw: [Int]) -> [WindowID] { desk.ids(raw) }

    @Test("an unplug holds the gone screen's Spaces, renumbering a taken name")
    func unplugHolds() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        #expect(core.profiles.currentName == "solo")
        // The DELL's 3 collides with solo's 3: past solo's last
        // live number (4) it is 5. Its 4 is free but would sit
        // below the 5, so it follows as 6 (#1664).
        #expect(
            core.state.heldSpaces[SpaceID(5)]
                == HeldOrigin(
                    name: SpaceID(3),
                    screen: dell.fingerprint,
                    icon: nil,
                    arrangement: .profile("desk")
                )
        )
        #expect(core.state.heldSpaces[SpaceID(6)]?.name == SpaceID(4))
        #expect(members(core, 5) == ids([10, 11]))
        #expect(members(core, 6) == ids([12]))
        #expect(members(core, 4).isEmpty)
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
        #expect(core.state.heldSpaces[SpaceID(6)] == nil)
        #expect(core.state.workspaces[SpaceID(6)] == nil)
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
        #expect(!kept.spaces.contains(SpaceID(6)))
        #expect(!kept.spaces.contains(SpaceID(5)))
        core.recordLivePartitioning()
        let record = core.state.profilePartitioning.remembered(for: "solo")
        #expect(record?[SpaceID(6)] == nil)
        #expect(record?[SpaceID(5)] == nil)
    }

    @Test("a held Space keeps the icon it had there, not the incoming one")
    func heldIconIsTheDepartingOne() throws {
        let core = try docked()
        // The incoming profile gives ITS 3 an icon (the device
        // repro: Glyphs' 3 wore headphones); the DELL's 3 had none.
        var solo = try core.profiles.read(name: "solo")
        solo.settings.spaceIcons[SpaceID(3)] = "headphones"
        try core.profiles.save(solo)
        core.execute("load_profile", args: [.string("desk")])
        core.tiler.settings.spaceIcons[SpaceID(4)] = "book"
        core.handle(.displaysChanged([builtIn]))
        #expect(core.state.heldSpaces[SpaceID(5)]?.icon == nil)
        #expect(core.state.heldSpaces[SpaceID(6)]?.icon == "book")
    }

    @Test("an unpinned Space of the gone screen is held too")
    func unpinnedSpaceIsHeld() throws {
        let core = try docked()
        // Main-role and auto-placed Spaces carry no pin; the
        // report-time screen record is what names their screen.
        core.spacePins[SpaceID(4)] = nil
        core.handle(.displaysChanged([builtIn]))
        #expect(
            core.state.heldSpaces[SpaceID(6)]?.screen == dell.fingerprint
        )
        #expect(members(core, 6) == ids([12]))
        #expect(core.state.settlingScreens.isEmpty)
    }

    @Test("an arrangement claiming a held number moves the held Space off it")
    func claimedHeldNumberIsReclaimed() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        var wide = try core.profiles.read(name: "solo")
        wide.spaces += [SpaceID(4), SpaceID(5)]
        wide.spaceModes[SpaceID(4)] = .bsp
        wide.spaceModes[SpaceID(5)] = .bsp
        core.apply(profile: wide, cause: .event)
        #expect(core.state.heldSpaces[SpaceID(4)] == nil)
        #expect(core.state.heldSpaces[SpaceID(5)] == nil)
        let held = core.state.heldSpaces
        #expect(held.count == 2)
        #expect(Set(held.values.map(\.name)) == [SpaceID(3), SpaceID(4)])
        for id in held.keys {
            #expect(!members(core, Int(id.raw)!).isEmpty)
        }
    }

    @Test("a held Space goes home only into the arrangement it left")
    func refileOnlyIntoTheOrigin() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        var other = try core.profiles.read(name: "desk")
        other.name = "other"
        core.state.workspaces.upsertDisplay(dell)
        core.apply(profile: other, cause: .event)
        #expect(core.state.heldSpaces[SpaceID(5)] != nil)
        #expect(core.spacePins[SpaceID(5)] == dell.fingerprint)
    }

    @Test("a config reload keeps a held Space's mode")
    func reloadKeepsHeldMode() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.setSpaceMode(SpaceID(5), .monocle)
        core.execute("reload_config")
        #expect(core.state.workspaces[SpaceID(5)]?.mode == .monocle)
    }

    @Test("delete_space ends a hold")
    func deleteEndsHold() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.execute("delete_space", args: [.string("5")])
        #expect(core.state.heldSpaces[SpaceID(5)] == nil)
        #expect(core.state.heldSpaces[SpaceID(6)] != nil)
    }

    @Test("the Settings draft never lists a held Space")
    func draftExcludesHeld() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.spacePins[SpaceID(5)] = dell.fingerprint
        let draft = core.loadGuiConfig()
        #expect(!draft.spaces.contains(SpaceID(6)))
        #expect(!draft.spaces.contains(SpaceID(5)))
        #expect(draft.spacePins[SpaceID(5)] == nil)
        let kept = core.buildProfile(
            name: "kept",
            modes: [SpaceID(5): .grid, SpaceID(1): .bsp]
        )
        #expect(kept.spaceModes[SpaceID(5)] == nil)
    }

    @Test("a Settings Save keeps a held Space it never listed")
    func settingsSaveKeepsHeld() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.setSpaceMode(SpaceID(5), .monocle)
        // The draft lists the captured Spaces only (ruling 5).
        var config = GuiConfig()
        config.spaces = core.capturedSpaces.map(\.id)
        core.applyProfileScopedState(from: config)
        #expect(core.state.heldSpaces[SpaceID(5)] != nil)
        #expect(members(core, 5) == ids([10, 11]))
        #expect(core.state.workspaces[SpaceID(5)]?.mode == .monocle)
    }

    @Test("Keep never saves a held Space's home pin")
    func keepDropsHeldPins() throws {
        let core = try docked()
        core.handle(.displaysChanged([builtIn]))
        core.spacePins[SpaceID(5)] = dell.fingerprint
        let kept = core.buildProfile(name: "kept", modes: nil)
        #expect(
            kept.monitorSets.first?.spaceMonitorMap[SpaceID(5)] == nil
        )
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
        let follower = try #require(
            items.first { $0.identity == .space(SpaceID(6)) }
        )
        #expect(follower.held?.originName == SpaceID(4))
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
