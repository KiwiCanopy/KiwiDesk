import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Every switch holds what the incoming arrangement does not name
/// (#1790, the owner's ruling of 2026-09-30): a Space with windows
/// is held for the arrangement it leaves, on whichever screen, an
/// empty one drops, and a Load ends only an empty hold. Replays the
/// held-Space desk, docked on `desk`.
@Suite("A switch holds what it does not name (#1790)", .serialized)
@MainActor
struct SwitchHoldTests {
    private let desk = HeldSpaceDesk()

    /// `desk`'s DELL Spaces 3 and 4 hold windows; `pair` names
    /// neither and keeps both screens.
    private func pair(_ core: KiwiCore) throws {
        try core.profiles.write(
            desk.profile(
                "pair",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: [SpaceID(1), SpaceID(2)]
            )
        )
    }

    @Test("a Load holds a Space it does not name; the return sends it home")
    func loadHoldsAndReturns() throws {
        let core = try desk.docked()
        try pair(core)
        core.execute("load_profile", args: [.string("pair")])
        for id in [SpaceID(3), SpaceID(4)] {
            #expect(core.state.heldSpaces[id]?.arrangement == .profile("desk"))
        }
        #expect(desk.members(core, 3) == desk.ids([10, 11]))
        #expect(!core.isTemporary(SpaceID(3)))
        core.execute("load_profile", args: [.string("desk")])
        #expect(core.state.heldSpaces.isEmpty)
        #expect(desk.members(core, 3) == desk.ids([10, 11]))
        #expect(desk.members(core, 4) == desk.ids([12]))
    }

    @Test("a Load ends an empty hold and keeps one with windows")
    func loadEndsOnlyEmptyHolds() throws {
        let core = try desk.docked()
        try pair(core)
        core.execute("load_profile", args: [.string("pair")])
        core.state.workspaces.add(WindowID(12), to: SpaceID(1))
        core.execute("load_profile", args: [.string("pair")])
        #expect(core.state.heldSpaces[SpaceID(3)] != nil)
        #expect(core.state.heldSpaces[SpaceID(4)] == nil)
        #expect(core.state.workspaces[SpaceID(4)] == nil)
    }

    @Test("an empty Space the incoming profile does not name drops")
    func emptyUnnamedDrops() throws {
        let core = try desk.docked()
        try pair(core)
        core.state.workspaces.add(WindowID(12), to: SpaceID(1))
        core.execute("load_profile", args: [.string("pair")])
        #expect(core.state.workspaces[SpaceID(4)] == nil)
        #expect(core.state.heldSpaces[SpaceID(4)] == nil)
    }

    @Test("a Standard taking over holds the profile's unplanned Spaces")
    func standardHoldsLeftovers() throws {
        LocalizationManager.shared.select("en")
        let mail = SpaceID("mail")
        let core = try desk.docked(dellSpaces: [mail])
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        #expect(!composed.spaces.contains(mail))
        core.apply(composed: composed, forceRetile: true)
        let origin = try #require(core.state.heldSpaces[mail])
        #expect(origin.arrangement == .profile("wide"))
        #expect(origin.screen == desk.dell.fingerprint)
        #expect(core.state.workspaces[mail]?.windows == [WindowID(100)])
        let display = try #require(core.state.workspaces.display(of: mail))
        let item = try #require(
            core.spaceBarItems(display: display, style: SpaceBarLook())
                .first { $0.identity == .space(mail) }
        )
        #expect(item.held?.profileName == "wide")
        core.execute("load_profile", args: [.string("wide")])
        #expect(core.state.heldSpaces[mail] == nil)
        #expect(core.state.workspaces[mail]?.windows == [WindowID(100)])
    }

    @Test("a held Space's sentence names its profile and screen")
    func sentenceNamesTheProfile() {
        LocalizationManager.shared.select("en")
        let view = SpaceBarItemView(frame: .zero)
        view.configure(
            identity: .space(SpaceID(3)),
            spaceGlyph: .text("3", tinted: false),
            apps: [],
            active: false,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(sticky: "", floating: ""),
            marker: .held(
                SpaceBarItemView.Held(
                    screenName: "DELL",
                    originName: nil,
                    profileName: "Desk"
                )
            )
        )
        #expect(
            view.spaceName(SpaceID(3), windows: 2)
                == "Space 3, held from Desk on DELL, not saved, windows: 2"
        )
    }

    /// The same exact set coming back applies nothing, so its pins
    /// are adopted on the spot; a temporary Space's pin is its own.
    @Test("an exact re-match keeps a temporary Space's pin")
    func exactRematchKeepsPin() throws {
        let core = try desk.docked()
        core.execute("create_space", args: [.string("7")])
        core.execute(
            "pin_space_to_display",
            args: [.string("7"), .string(desk.dell.fingerprint)]
        )
        core.handle(.displaysChanged([desk.builtIn, desk.dell]))
        #expect(core.spacePins[SpaceID(7)] == desk.dell.fingerprint)
    }

    /// The door's own retile reads the outgoing adoption; the bar
    /// and Settings must not keep what it saw.
    @Test("an incoming profile's new Space is never published as temporary")
    func adoptionRepublishes() throws {
        let core = try desk.docked()
        try core.profiles.write(
            desk.profile(
                "grown",
                screens: [desk.builtIn.fingerprint, desk.dell.fingerprint],
                spaces: (1...5).map { SpaceID($0) }
            )
        )
        core.execute("load_profile", args: [.string("grown")])
        #expect(!core.isTemporary(SpaceID(5)))
        #expect(!core.spaceBars.liveOnly.contains { $0.id == SpaceID(5) })
    }

    /// A Standard adopts its own pins; the hold must read the
    /// outgoing profile's first, with no settle record to fall
    /// back on — a same-count screen swap.
    @Test("a Standard holds a gone screen's Space under that screen")
    func standardHoldsTheGoneScreen() throws {
        let core = try desk.docked()
        let lg = Display(
            id: DisplayID(4),
            name: "LG",
            frame: desk.dell.frame
        )
        core.state.workspaces.removeDisplay(desk.dell.id)
        core.state.workspaces.upsertDisplay(lg)
        #expect(core.state.settlingScreens.isEmpty)
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        let held = try #require(
            core.state.heldSpaces.first { $0.value.name == SpaceID(3) }
        )
        #expect(held.value.screen == desk.dell.fingerprint)
    }

    /// No return could take a Space the outgoing profile never
    /// declared, so it is forwarded, not held.
    @Test("an init.lua Space the switch does not name is forwarded")
    func undeclaredSpaceIsForwarded() throws {
        let core = try desk.docked()
        let lua = SpaceID("lua")
        core.initDeclaredSpaces = [lua]
        core.state.workspaces.ensureSpace(lua)
        core.state.workspaces.add(WindowID(12), to: lua)
        try pair(core)
        core.execute("load_profile", args: [.string("pair")])
        #expect(core.state.heldSpaces[lua] == nil)
        #expect(!core.state.heldSpaces.values.contains { $0.name == lua })
    }

    @Test("a set pick on the live profile keeps a temporary pin")
    func setPickKeepsPin() throws {
        let core = try desk.docked()
        core.execute("create_space", args: [.string("7")])
        core.execute(
            "pin_space_to_display",
            args: [.string("7"), .string(desk.dell.fingerprint)]
        )
        try core.claimMonitorSet(
            [desk.builtIn.fingerprint, desk.dell.fingerprint],
            for: "desk"
        )
        #expect(core.spacePins[SpaceID(7)] == desk.dell.fingerprint)
    }

    @Test("a Standard's planned Space is never published as temporary")
    func standardRepublishes() throws {
        let core = try desk.docked()
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        let planned = Set(composed.spaces)
        #expect(
            !core.spaceBars.liveOnly.contains { planned.contains($0.id) }
        )
    }

    /// The top-up writes `gui.json`; a hold under its own number
    /// owes it nothing, so a switch leaves the file alone.
    @Test("a hold under its own number writes no digit row")
    func unrenumberedHoldWritesNoRow() throws {
        let core = try desk.docked()
        var config = GuiConfig()
        config.layers = [KeyLayer(name: KeyLayer.defaultName, bindings: [])]
        try core.guiConfigStore.save(config)
        core.execute("create_space", args: [.string("7")])
        core.state.workspaces.add(WindowID(12), to: SpaceID(7))
        try pair(core)
        // A Load mirrors its Spaces into the file too, so the rows
        // are what is compared.
        let rows = { core.guiConfigStore.load()?.layers.first?.bindings }
        let before = rows()
        core.execute("load_profile", args: [.string("pair")])
        #expect(core.state.heldSpaces[SpaceID(7)]?.name == SpaceID(7))
        #expect(rows() == before)
        // Vacuity: a top-up here does write.
        core.topUpDigitShortcuts()
        #expect(rows() != before)
    }
}
