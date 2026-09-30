import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space chip's New Space and Delete Space rows (#1790, the
/// owner's ruling of 2026-09-29): New Space mints the next free
/// number pinned to the chip's screen; Delete Space is offered
/// only for an empty Space and names a declared one's return; and
/// a changed Space set arms Keep as a mode change does.
@Suite("Space chip lifecycle rows", .serialized)
@MainActor
struct SpaceChipLifecycleRowsTests {
    private let display = Display(
        id: DisplayID(7),
        name: "Desk",
        frame: CGRect(x: 0, y: 0, width: 1000, height: 600)
    )
    private let one = SpaceID("1")
    private let two = SpaceID("2")

    /// Spaces 1 and 2 on one screen, 1 active and holding a window.
    private func seededCore() -> KiwiCore {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-chip-life-\(UUID())")
        )
        core.state.workspaces.upsertDisplay(display)
        core.state.workspaces.assign(one, to: display.id)
        core.state.workspaces.assign(two, to: display.id)
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

    /// The smallest free number, skipping one a remembered window
    /// names, pinned to the chip's screen.
    @Test("New Space mints the next free number on the chip's screen")
    func newSpace() {
        let core = seededCore()
        core.state.rememberedSpaces[WindowID(9)] = .departed(SpaceID("3"))
        perform(row(core, two, "New Space"))
        let minted = SpaceID("4")
        #expect(core.state.workspaces[minted] != nil)
        #expect(core.state.workspaces[SpaceID("3")] == nil)
        #expect(core.spacePins[minted] == display.fingerprint)
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

    @Test("Delete Space is greyed for a Space that holds anything")
    func deleteGreyed() {
        let core = seededCore()
        // A member.
        #expect(row(core, one, "Delete Space")?.enabled == false)
        // A window away on another Desktop, still filed there.
        core.state.awayWindows[WindowID(5)] = AwayWindow(
            id: WindowID(5),
            pid: 100,
            appName: "Away",
            appBundleID: "app.away",
            nativeSpace: 4
        )
        core.state.rememberedSpaces[WindowID(5)] = .departed(two)
        #expect(row(core, two, "Delete Space")?.enabled == false)
        core.state.awayWindows[WindowID(5)] = nil
        #expect(row(core, two, "Delete Space")?.enabled == true)
        // A held Space.
        core.state.heldSpaces[two] = HeldOrigin(
            name: SpaceID("3"),
            screen: "DELL:2560x1440",
            icon: nil,
            arrangement: nil
        )
        #expect(row(core, two, "Delete Space")?.enabled == false)
    }

    @Test("the only Space cannot be deleted")
    func onlySpace() {
        let core = seededCore()
        core.execute("delete_space", args: [.string("2")])
        core.state.apply(.windowDestroyed(WindowID(1), wasMinimized: false))
        #expect(core.state.workspaces.allSpaces.count == 1)
        #expect(row(core, one, "Delete Space")?.enabled == false)
    }

    @Test("a declared Space's Delete says it comes back")
    func declaredSubtitle() {
        let core = seededCore()
        core.initDeclaredSpaces = [two]
        #expect(
            row(core, two, "Delete Space")?.subtitle
                == "comes back on reload"
        )
    }

    /// Keep saves the whole live profile (#1179), so a changed
    /// Space set arms it as a changed mode does.
    @Test("a new Space arms Keep Layout in Profile")
    func keepArms() {
        let core = seededCore()
        let profile = core.buildProfile(name: "p", modes: nil)
        core.profiles.becameLive(profile, fits: true)
        let keep = { () -> BarMenuRow? in
            guard
                case .submenu(let layout)? = row(core, one, "Layout")?
                    .kind
            else { return nil }
            let title = "Keep Layout in Profile “p”"
            return layout.first { $0.title == title }
        }
        #expect(!core.spaceSetDrifted())
        #expect(keep()?.enabled == false)
        perform(row(core, one, "New Space"))
        #expect(core.spaceSetDrifted())
        #expect(keep()?.enabled == true)
    }
}
