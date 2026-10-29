import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket on screen (#2678, 2026-10-29 ruling): while Several
/// windows holds it, on every display, faded while empty, a count
/// badge from two inside; nothing at rest under One window; a click
/// lists the windows inside, each row taking its window out.
@Suite(
    "Pocket plate",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
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
        // A real screen, so the fallback square resolves (#531).
        if let screen = NSScreen.main, let id = screen.kiwiDisplayID,
            let space = core.state.workspaces.activeSpace
        {
            core.state.workspaces.upsertDisplay(
                Display(id: id, name: "Main", frame: screen.frame)
            )
            core.state.workspaces.assign(space, to: id)
        }
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        return core
    }

    private func several(_ core: KiwiCore) {
        core.execute("pocket.set_capacity", args: [.string("several")])
    }

    /// `one` and `two` marked and put in, through the keys.
    private func pocketTwo(_ core: KiwiCore) {
        several(core)
        for id in [one, two] {
            core.handle(.windowFocused(id))
            core.execute("toggle_pocket_window")
            core.execute("pocket")
        }
    }

    private func spec(_ core: KiwiCore) -> PocketPlateOverlay.Spec? {
        core.updatePocketPlate()
        return core.pocketPlate.specs.values.first
    }

    @Test("under One window nothing shows at rest")
    func oneShowsNothing() {
        let core = makeCore()
        core.handle(.windowFocused(one))
        core.execute("pocket")
        #expect(spec(core) == nil)
    }

    @Test("under Several it shows empty, faded, with no badge")
    func severalShowsEmpty() throws {
        let core = makeCore()
        several(core)
        let shown = try #require(spec(core))
        #expect(shown.faded)
    }

    @Test("one window inside lifts the fade")
    func oneInsideLifts() throws {
        let core = makeCore()
        several(core)
        core.handle(.windowFocused(one))
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        let shown = try #require(spec(core))
        #expect(!shown.faded)
        #expect(shown.windows == [one])
    }

    @Test("two inside: listed, and counted for VoiceOver alone")
    func twoInsideCounted() throws {
        let core = makeCore()
        pocketTwo(core)
        let shown = try #require(spec(core))
        #expect(!shown.faded)
        #expect(shown.windows == [one, two])
        // The pocket draws no count; its name carries it.
        #expect(shown.name.contains("2"))
    }

    @Test("a pocket stands on every display not standing down")
    func everyDisplay() throws {
        let core = makeCore()
        several(core)
        core.updatePocketPlate()
        let displays = Set(core.state.workspaces.allDisplays.map(\.id))
        #expect(Set(core.pocketPlate.specs.keys) == displays)
        let down = try #require(displays.first)
        core.pocketPlate.standingDown = [down]
        core.updatePocketPlate()
        #expect(core.pocketPlate.specs[down] == nil)
    }

    @Test("a bar edge's pinned slot is where the pocket stands")
    func standsOnTheSlot() throws {
        let core = makeCore()
        several(core)
        let display = try #require(
            core.state.workspaces.allDisplays.first?.id
        )
        let slot = CGRect(x: 1000, y: 860, width: 40, height: 40)
        core.updatePocketPlate(slots: [display: slot])
        let shown = try #require(core.pocketPlate.specs[display])
        #expect(
            shown.frame
                == GeometryUtils.flip(
                    slot,
                    primaryHeight: GeometryUtils.primaryHeight
                )
        )
    }

    @Test("Full lays no piece of its own; Hug and Boxed do")
    func platePieceFollowsTheFit() throws {
        let core = makeCore()
        several(core)
        let display = try #require(
            core.state.workspaces.allDisplays.first?.id
        )
        // A bar pass after each write re-reads the slots, so hand
        // the slot in after it.
        let slot = CGRect(x: 1000, y: 860, width: 40, height: 40)
        core.execute("kiwishelf.set_background_fit", args: [.string("full")])
        core.updatePocketPlate(slots: [display: slot])
        #expect(core.pocketPlate.specs[display]?.platePiece == false)
        core.execute("kiwishelf.set_background_fit", args: [.string("hug")])
        core.updatePocketPlate(slots: [display: slot])
        #expect(core.pocketPlate.specs[display]?.platePiece == true)
    }

    @Test("capacity is app-wide, decodes as stored, refuses a bad value")
    func capacityStored() throws {
        // App-wide (#2678): gui.json's `pocket` group.
        let group = try JSONDecoder().decode(
            AppWideSettings.Pocket.self,
            from: Data(#"{"capacity":"several"}"#.utf8)
        )
        let stored = AppWideSettings(
            refusal: AppWideSettings.Refusal(),
            quit: nil,
            pocket: group
        )
        #expect(stored?.pocketCapacity == .several)
        #expect(AppWideSettings().pocketCapacity == .one)
        let core = makeCore()
        #expect(
            !core.execute("pocket.set_capacity", args: [.string("many")])
                .isSuccess
        )
        #expect(core.appWide.pocketCapacity == .one)
        several(core)
        #expect(core.appWide.pocketCapacity == .several)
    }

    @Test("the list is a click-held list of the windows inside")
    func listSource() {
        let source = BarPeekSource.pocket([one, two])
        #expect(source.isList)
        #expect(source.clickGrowth == .outOfItem)
        #expect(source.header == .full)
        #expect(source.windows == [one, two])
    }

    @Test("a row of the list takes its window out")
    func rowTakesOut() {
        let core = makeCore()
        pocketTwo(core)
        #expect(core.state.pocketedWindows == [one, two])
        core.pickBarRow(one, on: nil)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.state.pocketPhase(of: two) == .pocketed)
    }

    @Test("a click grows the list out of that display's handle")
    func clickOpensTheList() throws {
        let core = makeCore()
        core.pocketPlate.ordersPanel = true
        // The handle stands on the real screen's edge.
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
        defer {
            core.shelves.peek.dismiss()
            core.shelves.peek.panel.panel?.orderOut(nil)
            core.pocketPlate.sync([])
        }
        pocketTwo(core)
        let display = try #require(
            core.state.workspaces.allDisplays.first?.id
        )
        // No bar edge: the handle, in a panel of its own.
        core.updatePocketPlate(slots: [:])
        let view = try #require(core.pocketPlate.view(on: display))
        let window = try #require(
            core.pocketPlate.panelForTesting(on: display)
        )
        #expect(core.shelves.shelfBeyondBars(window) != nil)
        core.pocketPlate.onClick(view)
        #expect(core.shelves.peek.shown?.view === view)
    }

    @Test("a hidden app's window counts for nothing")
    func untrackedCountsForNothing() {
        let core = makeCore()
        pocketTwo(core)
        core.state.apply(.windowHidden(one))
        #expect(core.pocketPlateWindows == [two])
    }
}
