import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket plate (#2678): on screen while two windows are inside,
/// widened for its count with its mark kept on the pocket, and a
/// click lists the windows inside, each row taking its window out.
@Suite("Pocket plate", .serialized)
@MainActor
struct PocketPlateTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let three = WindowID(3)

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-plate-\(UUID().uuidString)")
        )
        for raw: UInt32 in [3, 2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        return core
    }

    /// `one` and `two` marked and put in, through the keys.
    private func pocketTwo(_ core: KiwiCore) {
        core.execute("pocket.set_capacity", args: [.string("several")])
        for id in [one, two] {
            core.handle(.windowFocused(id))
            core.execute("toggle_pocket_window")
            core.execute("pocket")
        }
    }

    /// Shows the plate's panel, which a peek opens only on, with
    /// the peek's room pinned; `close` puts both away.
    private func showPanels(_ core: KiwiCore) {
        core.pocketPlate.ordersPanel = true
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
    }

    private func close(_ core: KiwiCore) {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        core.pocketPlate.sync(nil)
    }

    @Test("the plate shows from two windows inside")
    func showsFromTwo() {
        #expect(!KiwiCore.pocketPlateShows(inside: []))
        #expect(!KiwiCore.pocketPlateShows(inside: [one]))
        #expect(KiwiCore.pocketPlateShows(inside: [one, two]))
    }

    /// The active Space on the host's main screen, which the plate's
    /// frame is read on; nil on a host with none.
    private func giveSpaceTheMainScreen(_ core: KiwiCore) -> DisplayID? {
        guard let screen = NSScreen.main, let id = screen.kiwiDisplayID,
            let space = core.state.workspaces.activeSpace
        else { return nil }
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        // Pinned (tests.md, #531).
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        return id
    }

    @Test(
        "the bar pass shows the plate, and its stand-down hides it",
        .enabled(if: NSScreen.main != nil)
    )
    func barPassDrivesThePlate() throws {
        let core = makeCore()
        let display = try #require(giveSpaceTheMainScreen(core))
        pocketTwo(core)
        core.updateBars()
        let shown = try #require(core.pocketPlate.shown)
        #expect(shown.count == "2")
        #expect(shown.windows == [one, two])
        #expect(shown.display == display)
        // A switch back to One keeps both reachable.
        core.execute("pocket.set_capacity", args: [.string("one")])
        core.updateBars()
        #expect(core.pocketPlate.shown != nil)
        core.pocketPlate.standingDown = [display]
        core.updatePocketPlate()
        #expect(core.pocketPlate.shown == nil)
    }

    @Test(
        "a list open on the plate closes when the plate changes",
        .enabled(if: NSScreen.main != nil)
    )
    func changeClosesTheList() throws {
        let core = makeCore()
        _ = try #require(giveSpaceTheMainScreen(core))
        showPanels(core)
        defer { close(core) }
        pocketTwo(core)
        core.handle(.windowFocused(three))
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        // A hidden app's window is no row: the list names the rest.
        core.state.apply(.windowHidden(one))
        core.updateBars()
        core.openPocketList()
        #expect(core.shelves.peek.shown?.view === core.pocketPlate.view)
        #expect(core.shelves.peek.shown?.source == .pocket([two, three]))
        // Negative control: an unchanged plate keeps its list.
        core.updatePocketPlate()
        #expect(core.shelves.peek.shown?.view === core.pocketPlate.view)
        // The plate alone, no bar pass: a window leaves the list.
        core.state.markPocketOut(three, cameFrom: nil)
        core.updatePocketPlate()
        #expect(core.shelves.peek.shown == nil)
    }

    @Test(
        "the bar pass counts only the tracked windows inside",
        .enabled(if: NSScreen.main != nil)
    )
    func barPassCountsTracked() throws {
        let core = makeCore()
        _ = try #require(giveSpaceTheMainScreen(core))
        pocketTwo(core)
        core.handle(.windowFocused(three))
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        core.state.apply(.windowHidden(one))
        core.updateBars()
        let shown = try #require(core.pocketPlate.shown)
        #expect(shown.count == "2")
        #expect(shown.windows == [two, three])
    }

    @Test("the count widens the plate, its mark kept on the pocket")
    func widensAwayFromTheEdge() {
        let region = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let inside = CGRect(x: 100, y: 200, width: 40, height: 40)
        let free = KiwiCore.pocketPlateFrame(
            square: inside,
            extra: 20,
            region: region
        )
        #expect(free.frame.minX == inside.minX)
        #expect(free.frame.width == 60)
        #expect(free.frame.height == inside.height)
        #expect(!free.markTrailing)
        // At the right end — the right edge, or a position near 100
        // on the top or bottom — it widens leftward, mark trailing.
        let end = CGRect(x: 952, y: 200, width: 40, height: 40)
        let held = KiwiCore.pocketPlateFrame(
            square: end,
            extra: 20,
            region: region
        )
        #expect(held.frame.maxX == end.maxX)
        #expect(held.frame.width == 60)
        #expect(held.markTrailing)
        // The margin band decides, from both sides of its edge.
        let margin = BriefPocketPlan.margin
        let edge = region.maxX - margin - 20 - 40
        for (x, trails) in [(edge + 1, true), (edge - 1, false)] {
            let square = CGRect(x: x, y: 200, width: 40, height: 40)
            let placed = KiwiCore.pocketPlateFrame(
                square: square,
                extra: 20,
                region: region
            )
            #expect(placed.markTrailing == trails, "x \(x)")
        }
    }

    @Test(
        "a play draws its own pocket only where no plate stands after it",
        .enabled(if: NSScreen.main != nil)
    )
    func playDrawsWhereNoPlate() throws {
        let core = makeCore()
        let display = try #require(giveSpaceTheMainScreen(core))
        pocketTwo(core)
        core.updateBars()
        #expect(!core.briefPocketDrawsPocket(on: display))
        // A take-out plays before its retile: the plate it leaves
        // behind is gone, so the play draws the pocket.
        core.state.markPocketOut(one, cameFrom: nil)
        #expect(core.briefPocketDrawsPocket(on: display))
    }

    @Test(
        "a take-out of two draws the pocket, a put-in to two flies in",
        .enabled(if: NSScreen.main != nil)
    )
    func playsReadThePlateTheyLeave() throws {
        let core = makeCore()
        _ = try #require(giveSpaceTheMainScreen(core))
        pocketTwo(core)
        core.updateBars()
        // Plays, panel and frame clock inert, as `BriefPocketTests`.
        core.briefPocket.reduceMotion = { false }
        core.briefPocket.present = { _ in }
        core.briefPocket.makeFrames = { _, _ in nil }
        core.execute("pocket")
        #expect(try #require(core.briefPocket.playing).drawsPocket)
        core.briefPocket.end()
        core.execute("pocket")
        #expect(try !#require(core.briefPocket.playing).drawsPocket)
        core.briefPocket.end()
    }

    @Test(
        "a bar pass with screens hands the plate its stand-down",
        .enabled(if: NSScreen.main != nil)
    )
    func screenPassHandsTheStandDown() throws {
        let core = makeCore()
        _ = try #require(giveSpaceTheMainScreen(core))
        // A stale verdict the pass must overwrite.
        core.pocketPlate.standingDown = [DisplayID(99)]
        core.updateBars()
        #expect(!core.pocketPlate.standingDown.contains(DisplayID(99)))
        #expect(
            core.pocketPlate.standingDown
                == core.overflowMarks.standingDown
        )
    }

    @Test("the bar pass hands the plate its own stand-down")
    func barPassHandsTheStandDown() {
        let core = makeCore()
        // A stale verdict the pass must overwrite.
        core.pocketPlate.standingDown = [DisplayID(99)]
        core.updateBars()
        #expect(
            core.pocketPlate.standingDown
                == core.overflowMarks.standingDown
        )
    }

    @Test("capacity decodes as stored, absent as one, and refuses a bad value")
    func capacityStored() throws {
        let set = try JSONDecoder().decode(
            PocketStyle.self,
            from: Data(#"{"capacity":"several"}"#.utf8)
        )
        #expect(set.capacity == .several)
        let absent = try JSONDecoder().decode(
            PocketStyle.self,
            from: Data("{}".utf8)
        )
        #expect(absent.capacity == .one)
        let core = makeCore()
        #expect(
            !core.execute("pocket.set_capacity", args: [.string("many")])
                .isSuccess
        )
        #expect(core.tiler.settings.pocketStyle.capacity == .one)
    }

    @Test("the plate's list is a click-held list of the windows inside")
    func listSource() {
        let source = BarPeekSource.pocket([one, two])
        #expect(source.isList)
        #expect(source.clickGrowth == .outOfItem)
        #expect(source.header == .full)
        #expect(source.windows == [one, two])
    }

    @Test("a row of the plate's list takes its window out")
    func rowTakesOut() {
        let core = makeCore()
        pocketTwo(core)
        #expect(core.state.pocketedWindows == [one, two])
        core.pickBarRow(one, on: nil)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.state.pocketPhase(of: two) == .pocketed)
    }

    @Test("a click grows the list out of the plate, wearing its shelf")
    func clickOpensTheList() throws {
        let core = makeCore()
        showPanels(core)
        defer { close(core) }
        pocketTwo(core)
        core.pocketPlate.sync(
            PocketPlateOverlay.Spec(
                display: DisplayID(1),
                windows: [one, two],
                frame: CGRect(x: 100, y: 100, width: 60, height: 40),
                shelf: KiwiShelf(),
                markHex: "",
                count: "2",
                markTrailing: false,
                name: "Pocket"
            )
        )
        let window = try #require(core.pocketPlate.panel)
        #expect(core.shelves.shelfBeyondBars(window) != nil)
        core.openPocketList()
        #expect(core.shelves.peek.shown?.view === core.pocketPlate.view)
    }

    @Test("a hidden app's window counts for nothing on the plate")
    func untrackedCountsForNothing() {
        let core = makeCore()
        pocketTwo(core)
        core.state.apply(.windowHidden(one))
        #expect(core.pocketPlateWindows == [two])
    }
}
