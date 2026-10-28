import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Marking the pocket window (#2675): `toggle_pocket_window` marks
/// the focused window and floats it as a Float does, unmarks it
/// into the tiling (#2680), and refuses a second window; `pocket`
/// then acts on the marked window alone.
@Suite("Pocket window mark", .serialized)
@MainActor
struct PocketWindowTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
    private let slot = CGRect(x: 0, y: 0, width: 800, height: 1000)

    /// Space 1 in bsp with w1 (focused) and w2 tiled. The animation
    /// engine is off so a placement lands on the `apply` hook.
    private func makeCore(
        applied: @escaping @MainActor (WindowID, CGRect) -> Void = {
            _,
            _ in
        }
    ) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-pocket-mark-\(UUID().uuidString)"
                )
        )
        // Pin the display (#531): the placement reads through it.
        let screen = self.screen
        core.tiler.visibleBounds = { _ in screen }
        core.execute("set_mode", args: [.string("1"), .string("bsp")])
        for raw: UInt32 in [2, 1] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 900_000 + pid_t(raw),
                        appName: "App\(raw)",
                        title: "Window \(raw)",
                        frame: slot
                    )
                )
            )
        }
        core.state.apply(.windowFocused(one))
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
        return core
    }

    @Test("marking floats the window out where it is, on every Space")
    func marks() {
        let core = makeCore()
        #expect(core.execute("toggle_pocket_window").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.state.workspaces.space(of: one) == SpaceID("1"))
        #expect(core.state.windows[one]?.isFloating == true)
        #expect(core.state.windows[one]?.stickyScope == .global)
        #expect(core.state.pocketPhase(of: two) == nil)
    }

    @Test("marking a tiled window places it as a Float does")
    func marksAtTheFloatSize() throws {
        var frames: [WindowID: CGRect] = [:]
        let core = makeCore { frames[$0] = $1 }
        let region = try #require(
            core.floatGrowBounds(on: SpaceID("1"))
        )
        core.execute("toggle_pocket_window")
        #expect(frames[one] == FloatPlacement.centered(in: region))
    }

    /// A window already floating keeps its frame (owner, #2675).
    @Test("marking a window already floating keeps its frame")
    func floatKeepsItsFrame() {
        var placed: [WindowID] = []
        let core = makeCore { id, _ in placed.append(id) }
        core.execute("toggle_floating")
        placed.removeAll()
        core.state.apply(.windowResized(one, slot))
        core.execute("toggle_pocket_window")
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(!placed.contains(one))
    }

    @Test("pocket acts on the marked window, from any window")
    func pocketActsOnTheMark() {
        let core = makeCore()
        core.execute("toggle_pocket_window")
        core.state.apply(.windowFocused(two))
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
        #expect(core.state.pocketPhase(of: two) == nil)
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocketPhase(of: one) == .out)
    }

    @Test("a second window is refused, and the mark stays put")
    func secondWindowRefused() {
        let core = makeCore()
        core.execute("toggle_pocket_window")
        core.state.apply(.windowFocused(two))
        #expect(!core.execute("toggle_pocket_window").isSuccess)
        #expect(core.state.pocket.first?.window == one)
        #expect(core.state.pocketPhase(of: one) == .out)
        #expect(core.state.windows[two]?.isFloating == false)
    }

    /// The pill resolves the refusal's sentinel to the pocket
    /// drawing, which no system symbol of that name could supply.
    @Test("the pill draws the pocket's taken glyph")
    @MainActor
    func pillDrawsTheTakenGlyph() {
        let taken = SizeLimitPillPlate.image(for: PocketMark.takenName)
        #expect(taken != nil)
        #expect(taken?.isTemplate == false)
        #expect(SizeLimitPillPlate.image(for: "nosign") != nil)
    }

    @Test("a second window is refused while the mark is pocketed")
    func pocketedMarkRefusesAnother() {
        let core = makeCore()
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        #expect(core.focusedWindowID == two)
        #expect(!core.execute("toggle_pocket_window").isSuccess)
        #expect(core.state.pocket.first?.window == one)
        #expect(core.state.pocketPhase(of: one) == .pocketed)
    }

    /// Unmarking tiles the window, as a Tile does (owner, #2680).
    @Test("unmarking tiles the window on the Space shown")
    func unmarks() {
        let core = makeCore()
        core.execute("toggle_pocket_window")
        #expect(core.execute("toggle_pocket_window").isSuccess)
        #expect(core.state.pocket.isEmpty)
        #expect(core.state.windows[one]?.isFloating == false)
        #expect(core.state.windows[one]?.stickyScope == StickyScope.none)
        #expect(!core.state.userFloated.contains(one))
        #expect(core.state.workspaces.space(of: one) == SpaceID("1"))
    }

    @Test("unmarked on another Space, it stays on that one")
    func unmarkRefilesOntoTheActiveSpace() {
        let core = makeCore()
        core.execute("toggle_pocket_window")
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.activate(SpaceID("2"))
        core.state.workspaces.add(two, to: SpaceID("2"))
        core.state.apply(.windowFocused(one))
        #expect(core.focusedWindowID == one)
        var moved: [KiwiNotification] = []
        core.bus.addSink { event, _ in moved.append(event) }
        core.execute("toggle_pocket_window")
        #expect(core.state.workspaces.space(of: one) == SpaceID("2"))
        #expect(core.state.pocket.isEmpty)
        // Filed as a user move files a window, so it is announced.
        #expect(moved.contains(.windowMovedToSpace))
    }

    /// The slot fills only through the mark: the pocketing
    /// transition refuses a window that is not the out slot's.
    @Test("an unmarked window cannot be pocketed directly")
    func pocketingNeedsTheMark() {
        let core = makeCore()
        core.state.pocketWindow(one)
        #expect(core.state.pocket.isEmpty)
        #expect(core.state.workspaces.space(of: one) == SpaceID("1"))
    }

    @Test("with nothing marked, pocket marks and pockets the focus")
    func pocketFallsBackToTheFocus() {
        let core = makeCore()
        core.execute("toggle_pocket_window")
        core.execute("toggle_pocket_window")
        core.state.apply(.windowFocused(two))
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.pocket.first?.window == two)
        #expect(core.state.pocketPhase(of: two) == .pocketed)
    }

    /// Puts Space 1 on the host's first screen and pins the layout
    /// to its usable area, so a frame placed there is one the park
    /// files under that screen. Returns the area.
    private func pinHostScreen(_ core: KiwiCore) throws -> CGRect {
        let screen = try #require(ScreenList.all.first)
        let id = try #require(screen.kiwiDisplayID)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(SpaceID("1"), to: id)
        let area = GeometryUtils.axVisibleFrame(of: screen)
        core.tiler.visibleBounds = { _ in area }
        return area
    }

    /// A core whose windows follow every frame sent, as a real app
    /// does, so the park files the frame the window stands at.
    private func makeFollowingCore(
        sent: @escaping @MainActor (WindowID, CGRect) -> Void = { _, _ in }
    ) -> KiwiCore {
        weak var core: KiwiCore?
        let made = makeCore { id, frame in
            sent(id, frame)
            core?.state.apply(.windowResized(id, frame))
        }
        core = made
        return made
    }

    /// The fallback marks the window, so the frame the park files
    /// is its float placement (#2672), not the tiled slot it had.
    @Test("the fallback files the float placement at the park")
    func fallbackPlacesBeforeThePark() throws {
        let core = makeFollowingCore()
        _ = try pinHostScreen(core)
        let placed = try #require(core.floatPlacementFrame(for: one))
        #expect(placed != slot)
        core.execute("pocket")
        #expect(core.state.pocket.first?.frames.values.map(\.self) == [placed])
    }

    /// The fallback on a window already floating files the frame
    /// it stands at (owner, #2675).
    @Test("the fallback files a float's own frame")
    func fallbackKeepsAFloatsFrame() throws {
        let core = makeFollowingCore()
        let area = try pinHostScreen(core)
        core.execute("toggle_floating")
        let own = CGRect(
            x: area.minX + 60,
            y: area.minY + 60,
            width: 420,
            height: 260
        )
        core.state.apply(.windowResized(one, own))
        core.execute("pocket")
        #expect(
            core.state.pocket.first?.frames.values.map(\.size) == [own.size]
        )
    }

    /// A take-out never resizes (owner, #2675): it restores the
    /// frame filed at the park, here a size the user gave it after
    /// the mark. Reads the host's first screen, which the filing
    /// looks the frame up on.
    @Test("a take-out keeps a hand-resized size")
    func takeOutKeepsTheSize() throws {
        let core = makeFollowingCore()
        let area = try pinHostScreen(core)
        let hand = CGRect(
            x: area.minX + 40,
            y: area.minY + 40,
            width: 500,
            height: 300
        )
        core.execute("toggle_pocket_window")
        core.state.apply(.windowResized(one, hand))
        core.execute("pocket")
        let filed = try #require(
            core.state.pocket.first?.frames.values.first
        )
        #expect(filed.size == hand.size)
        // Parked off the corner, at a size of its own, so a take-out
        // centring the window's current size reads apart from one
        // restoring the filed frame.
        let parked = CGRect(
            x: area.maxX - 1,
            y: area.maxY - 1,
            width: 320,
            height: 200
        )
        core.state.apply(.windowResized(one, parked))
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: one) == .out)
        // The frame the take-out seeds: still pending, or already
        // sent and stood at.
        let back = try #require(
            core.tiler.stashOriginal(one) ?? core.state.windows[one]?.frame
        )
        // The size: a delivered frame may be nudged into the grow
        // bounds, and a centring fallback keeps the parked size.
        #expect(back.size == filed.size)
    }

    @Test("a slot whose app is gone frees the mark for the focus")
    func goneSlotFreesTheMark() {
        let core = makeCore()
        core.execute("pocket")
        core.state.apply(.windowHidden(one))
        core.eventLoop.processIdentity.runs = { _ in false }
        core.state.apply(.windowFocused(two))
        #expect(core.execute("toggle_pocket_window").isSuccess)
        #expect(core.state.pocket.first?.window == two)
        #expect(core.state.pocketPhase(of: two) == .out)
    }

    @Test("⌃⌥⇧P marks, seeded and offered as generation 9")
    func defaultRow() {
        let row = DefaultKeybindings.pocketWindowRow()
        #expect(row.combo == "control+option+shift+p")
        #expect(row.lua == "KiwiDesk.toggle_pocket_window()")
        #expect(DefaultKeybindings.rows(ofGeneration: 9) == [row])
        #expect(
            DefaultKeybindings.bindings(
                spaces: [SpaceID("1")],
                resizeStep: 50,
                base: .standard
            ).contains(row)
        )
        #expect(
            DefaultKeybindings.generationTopUp(
                existing: [],
                above: 8,
                base: .standard
            ) == [row]
        )
    }
}
