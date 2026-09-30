import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space chip's New Space and Delete Space rows (#1790, the
/// owner's ruling of 2026-09-29): New Space mints the next free
/// number pinned to the chip's screen; Delete Space is offered
/// only for an empty Space and names a declared one's return; and
/// Keep keeps layouts alone, so a changed Space set never arms it
/// (the 2026-09-30 ruling).
@Suite("Space chip lifecycle rows", .serialized)
@MainActor
struct SpaceChipLifecycleRowsTests {
    private let display = Display(
        id: DisplayID(7),
        name: "Desk",
        frame: CGRect(x: 0, y: 0, width: 1000, height: 600)
    )
    private let side = Display(
        id: DisplayID(8),
        name: "Side",
        frame: CGRect(x: 1000, y: 0, width: 800, height: 600)
    )
    private let one = SpaceID("1")
    private let two = SpaceID("2")
    private let three = SpaceID("3")

    /// Spaces 1 and 2 on the main screen, 1 active and holding a
    /// window; Space 3 alone on a second screen, pinned there.
    private func seededCore() -> KiwiCore {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-chip-life-\(UUID())")
        )
        core.state.workspaces.upsertDisplay(display)
        core.state.workspaces.assign(one, to: display.id)
        core.state.workspaces.assign(two, to: display.id)
        core.state.workspaces.upsertDisplay(side)
        core.state.workspaces.assign(three, to: side.id)
        core.spacePins[three] = side.fingerprint
        core.state.workspaces.activate(one)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 41, appName: "App")
            )
        )
        return core
    }

    private func row(_ core: KiwiCore, _ id: SpaceID, _ title: String)
        -> BarMenuRow?
    {
        core.barMenuRows(.space(id)).first { $0.title == title }
    }

    private func perform(_ row: BarMenuRow?) {
        guard case .action(let perform)? = row?.kind else {
            Issue.record("\(row?.title ?? "nil") is not an action")
            return
        }
        perform()
    }

    @Test("the rows sit between the chip rows and the shelf")
    func rowOrder() {
        let core = seededCore()
        let titles = core.barMenuRows(.space(one)).map {
            $0.isSeparator ? "—" : $0.title
        }
        #expect(
            Array(titles.suffix(8))
                == [
                    "Space Settings…", "—", "New Space", "Delete Space",
                    "—", "KiwiShelf Settings…", "Looks…",
                    "Advanced Colors…",
                ]
        )
    }

    /// The SMALLEST number nothing names — a remembered window's
    /// Space, a declared one — pinned to the chip's own screen.
    /// The gap at 6 tells the smallest free from one past the
    /// highest (8).
    @Test("New Space mints the smallest free number on the chip's screen")
    func newSpace() {
        let core = seededCore()
        for (raw, space) in [(UInt32(9), "4"), (10, "7")] {
            core.state.rememberedSpaces[WindowID(raw)] =
                .departed(SpaceID(space))
        }
        core.initDeclaredSpaces = [SpaceID("5")]
        perform(row(core, three, "New Space"))
        let minted = SpaceID("6")
        #expect(core.state.workspaces[minted] != nil)
        for untouched in ["4", "5", "7"] {
            #expect(core.state.workspaces[SpaceID(untouched)] == nil)
        }
        #expect(core.spacePins[minted] == side.fingerprint)
    }

    /// The number is read at the click, not when the menu opened.
    @Test("New Space takes the number free at the click")
    func numberAtClick() throws {
        let core = seededCore()
        let new = try #require(row(core, three, "New Space"))
        core.execute("create_space", args: [.string("4")])
        perform(new)
        #expect(core.state.workspaces[SpaceID("5")] != nil)
        #expect(core.spacePins[SpaceID("5")] == side.fingerprint)
    }

    @Test("Delete Space deletes an empty Space")
    func deleteEmpty() {
        let core = seededCore()
        let delete = row(core, two, "Delete Space")
        #expect(delete?.enabled == true)
        #expect(delete?.subtitle == nil)
        perform(delete)
        #expect(core.state.workspaces[two] == nil)
    }

    /// Greyed for a window the user sees, or a hold; a window away
    /// or hidden does not block it and comes back as a new one
    /// would (#1790, owner 2026-09-30).
    @Test("Delete Space is greyed for a window in it or a hold")
    func deleteGreyed() {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        // A member.
        #expect(row(core, one, "Delete Space")?.enabled == false)
        #expect(
            row(core, one, "Delete Space")?.subtitle == "Still has windows"
        )
        // A window away on another Desktop, still filed there.
        core.state.awayWindows[WindowID(5)] = AwayWindow(
            id: WindowID(5),
            pid: 100,
            appName: "Away",
            appBundleID: "app.away",
            nativeSpace: 4
        )
        core.state.rememberedSpaces[WindowID(5)] = .departed(two)
        #expect(row(core, two, "Delete Space")?.enabled == true)
        core.state.awayWindows[WindowID(5)] = nil
        core.state.rememberedSpaces[WindowID(5)] = nil
        #expect(row(core, two, "Delete Space")?.enabled == true)
        // A held Space.
        core.state.heldSpaces[two] = HeldOrigin(
            name: SpaceID("3"),
            screen: "DELL:2560x1440",
            icon: nil,
            arrangement: .profile("Desk")
        )
        #expect(row(core, two, "Delete Space")?.enabled == false)
        #expect(
            row(core, two, "Delete Space")?.subtitle == "Goes back to Desk"
        )
    }

    /// The #1175 heal would re-mint a screen's last Space the
    /// moment it went, so the row does not offer it.
    @Test("a screen's last Space cannot be deleted")
    func lastOnScreen() {
        LocalizationManager.shared.select("en")
        let core = seededCore()
        #expect(core.state.workspaces[three]?.windows.isEmpty == true)
        #expect(row(core, three, "Delete Space")?.enabled == false)
        #expect(
            row(core, three, "Delete Space")?.subtitle
                == "The only Space on this screen"
        )
    }

    /// A hidden app's window is not one the user sees, so it does
    /// not block Delete; it comes back as a new window would.
    @Test("a hidden app's returning window leaves Delete on")
    func hiddenWindowDoesNotBlock() {
        let core = seededCore()
        core.state.rememberedSpaces[WindowID(6)] = .departed(two)
        #expect(row(core, two, "Delete Space")?.enabled == true)
    }

    @Test("a declared Space's Delete says it comes back")
    func declaredSubtitle() {
        let core = seededCore()
        core.initDeclaredSpaces = [two]
        #expect(
            row(core, two, "Delete Space")?.subtitle
                == "init.lua brings it back on reload"
        )
    }

    private func keep(_ core: KiwiCore) -> BarMenuRow? {
        guard
            case .submenu(let layout)? = row(core, one, "Layout")?.kind
        else { return nil }
        let title = "Keep Layout in Profile “p”"
        return layout.first { $0.title == title }
    }

    /// Keep keeps the layouts of the profile's own Spaces (#1179,
    /// re-ruled by #1790): a New Space arms nothing, a temporary
    /// Space's mode arms nothing, and a profile Space's does — and
    /// Keep writes that mode alone, never the Space list.
    @Test("Keep keeps layouts, never the Space set")
    func keepKeepsLayouts() throws {
        let core = seededCore()
        let profile = core.buildProfile(name: "p", modes: nil)
        try core.profiles.save(profile)
        core.profiles.becameLive(profile, fits: true)
        #expect(keep(core)?.enabled == false)
        perform(row(core, one, "New Space"))
        let minted = try #require(
            core.state.workspaces.allSpaces.map(\.id).first {
                !profile.declaredSpaces.contains($0)
            }
        )
        #expect(core.isTemporary(minted))
        #expect(keep(core)?.enabled == false)
        core.execute(
            "set_mode",
            args: [.string(minted.raw), .string("monocle")]
        )
        core.state.workspaces.activate(minted)
        #expect(keep(core)?.enabled == false)
        core.state.workspaces.activate(one)
        core.execute("set_mode", args: [.string(one.raw), .string("stack")])
        #expect(keep(core)?.enabled == true)
        try core.keepLayouts()
        let stored = try core.profiles.read(name: "p")
        #expect(stored.spaceModes[one] == .stack)
        #expect(stored.spaces == profile.spaces)
        #expect(!stored.declaredSpaces.contains(minted))
        #expect(keep(core)?.enabled == false)
    }
}
