import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// Two pocketable windows on the real main screen, the Space Bar at the
/// top, so the pocket's own edge draws nothing; One window by default.
/// The pocket's real panels order in, so its suites need a main screen.
@MainActor
private struct PocketListFixture {
    let one = WindowID(1)
    let two = WindowID(2)
    let core: KiwiCore
    let display: DisplayID

    init() throws {
        core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-list-\(UUID().uuidString)")
        )
        for id in [one, two] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: id,
                        pid: 900_000 + pid_t(id.raw),
                        appName: "App\(id.raw)",
                        title: "Window \(id.raw)",
                        frame: CGRect(x: 100, y: 100, width: 600, height: 400)
                    )
                )
            )
        }
        let screen = try #require(NSScreen.main)
        display = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: display, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: display)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 800)
        }
        core.tiler.settings.spaceBarStyle.edge = .top
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.tiler.settings.kiwishelf.pocketEdge = .bottom
        core.pocketPlate.ordersPanel = true
        core.shelves.peek.visibleArea = { _ in
            CGRect(x: -20_000, y: -20_000, width: 40_000, height: 40_000)
        }
    }

    func tearDown() {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        core.pocketPlate.sync([])
        NativeSpaces.currentSpaceIsUserOverride = nil
    }

    /// Pockets `ids`, Several windows holding them.
    func pocket(_ ids: [WindowID]) {
        core.execute("pocket.set_capacity", args: [.string("several")])
        for id in ids {
            core.handle(.windowFocused(id))
            core.execute("toggle_pocket_window")
            core.execute("pocket")
            #expect(core.state.isPocketed(id))
        }
        core.updatePocketPlate(slots: [:])
    }
}

/// A key-opened pocket list (#2974 ▸ Ruling 4): a row lifted, and the
/// arrows and Return walking it with the chord's ⌘ still held.
@Suite(
    "A key-opened pocket list takes the keyboard",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketListKeyboardTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private static let down: UInt16 = 125
    private static let up: UInt16 = 126
    private static let enter: UInt16 = 36
    private static let escape: UInt16 = 53

    @Test("the key lifts the first row; a click lifts none")
    func keyLiftsTheFirstRow() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let view = try #require(core.pocketPlate.view(on: display))
        core.pocketPlate.onClick(view)
        #expect(core.shelves.peek.panel.body.hovered == nil)
        core.execute("pocket.toggle_list")
        #expect(core.shelves.peek.shown == nil)
        core.execute("pocket.toggle_list")
        expectEqual(core.shelves.peek.panel.body.hovered, 0)
        // Closed and reopened, it starts over at the first row, inside
        // the close's landing and past it.
        let walked = core.shelves.peek.panel
        var landings: [@MainActor () -> Void] = []
        core.shelves.peek.schedule = { _, body in landings.append(body) }
        #expect(walked.morphKey(Self.down))
        core.execute("pocket.toggle_list")
        #expect(walked.leaving != nil)
        core.execute("pocket.toggle_list")
        expectEqual(walked.body.hovered, 0)
        #expect(walked.morphKey(Self.down))
        core.execute("pocket.toggle_list")
        landings.forEach { $0() }
        #expect(walked.morph == nil)
        core.execute("pocket.toggle_list")
        expectEqual(walked.body.hovered, 0)
        // A redraw of the list keeps the row the arrows reached.
        let panel = core.shelves.peek.panel
        #expect(panel.morphKey(Self.down))
        expectEqual(panel.body.hovered, 1)
        // A pointer leaving its row, or a press off every row, leaves
        // the row to Return; a click's list drops it (`clickDropsHover`).
        panel.body.mouseExited(with: pointerEvent())
        expectEqual(panel.body.hovered, 1)
        panel.body.press(at: CGPoint(x: -50, y: -50))
        expectEqual(panel.body.hovered, 1)
        panel.body.pressed = 0
        panel.body.drag(to: CGPoint(x: -50, y: -50))
        expectEqual(panel.body.hovered, 1)
        panel.body.pressed = nil
        core.shelves.peek.show(
            try #require(core.pocketPlate.view(on: display)),
            source: .pocket(core.pocketPlateWindows),
            space: nil,
            edge: .bottom
        )
        expectEqual(panel.body.hovered, 1)
        expectEqual(core.shelves.peek.shown?.keyed, true)
    }

    @Test("the arrows walk the rows, Return picks, Esc closes")
    func keysWalkAndPick() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        core.execute("pocket.toggle_list")
        var picked: [WindowID] = []
        core.shelves.peek.pick = { id, _ in picked.append(id) }
        let panel = core.shelves.peek.panel
        #expect(panel.morphKey(Self.down))
        #expect(panel.morphKey(Self.up))
        expectEqual(panel.body.hovered, 0)
        #expect(panel.morphKey(Self.down))
        #expect(panel.morphKey(Self.enter))
        expectEqual(picked, [two])
        #expect(core.shelves.peek.shown == nil)
        core.execute("pocket.toggle_list")
        #expect(core.shelves.peek.shown != nil)
        #expect(panel.morphKey(Self.escape))
        #expect(core.shelves.peek.shown == nil)
    }

    /// The chord's ⌘ is still held as the first arrow lands, which
    /// AppKit offers as a key equivalent ahead of `keyDown`.
    @Test("an arrow with the chord's ⌘ held walks; ⌘Q closes unquit")
    func commandHeldWalks() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        core.execute("pocket.toggle_list")
        let panel = core.shelves.peek.panel
        let window = try #require(panel.panel)
        #expect(
            window.performKeyEquivalent(with: key(Self.down, "\u{F701}"))
        )
        expectEqual(panel.body.hovered, 1)
        #expect(core.shelves.peek.shown != nil)
        #expect(
            window.performKeyEquivalent(with: key(Self.up, "\u{F700}"))
        )
        expectEqual(panel.body.hovered, 0)
        var picked: [WindowID] = []
        core.shelves.peek.pick = { id, _ in picked.append(id) }
        #expect(window.performKeyEquivalent(with: key(Self.enter, "\r")))
        expectEqual(picked, [one])
        core.execute("pocket.toggle_list")
        #expect(window.performKeyEquivalent(with: key(76, "\u{3}")))
        expectEqual(picked, [one, one])
        core.execute("pocket.toggle_list")
        #expect(window.performKeyEquivalent(with: key(12, "q")))
        #expect(core.shelves.peek.shown == nil)
    }

    private func pointerEvent() -> NSEvent {
        NSEvent.enterExitEvent(
            with: .mouseExited,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            trackingNumber: 0,
            userData: nil
        )!
    }

    @Test("a click's list drops its row as the pointer leaves it")
    func clickDropsHover() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let view = try #require(core.pocketPlate.view(on: display))
        core.pocketPlate.onClick(view)
        let body = core.shelves.peek.panel.body
        body.setHovered(0)
        body.mouseExited(with: pointerEvent())
        #expect(body.hovered == nil)
    }

    @Test("a click's list closes on a ⌘ arrow, walking nothing")
    func clickListCloses() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let view = try #require(core.pocketPlate.view(on: display))
        core.pocketPlate.onClick(view)
        let window = try #require(core.shelves.peek.panel.panel)
        #expect(
            window.performKeyEquivalent(with: key(Self.down, "\u{F701}"))
        )
        #expect(core.shelves.peek.shown == nil)
        #expect(core.shelves.peek.panel.body.hovered == nil)
    }

    private func key(_ code: UInt16, _ text: String) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control, .option, .command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: text,
            charactersIgnoringModifiers: text,
            isARepeat: false,
            keyCode: code
        )!
    }

    @Test("the lift starts on a window, past a tall list's more line")
    func liftSkipsTheMoreLine() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let content = try #require(
            core.barPeekContent(.pocket(core.pocketPlateWindows), on: nil)
        )
        let body = BarPeekBody()
        _ = body.build(
            content,
            shelf: KiwiShelf(),
            maxHeight: 60,
            cutAtTop: true
        )
        expectEqual(body.targets.first?.action, .more)
        body.liftRow(nil)
        let lifted = try #require(body.hovered)
        #expect(lifted > 0)
        // A row past a shrunken list lands on its last.
        body.liftRow(9)
        expectEqual(body.hovered, body.targets.count - 1)
    }

    @Test("an empty pocket shows its empty state, its first row lifted")
    func emptyShowsItsState() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        core.execute("pocket.toggle_list")
        let panel = core.shelves.peek.panel
        #expect(panel.drawn?.empty != nil)
        expectEqual(panel.body.hovered, 0)
    }

    @Test("it acts on no window: out of the foreground preflight")
    func noFocusImplied() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        #expect(!core.impliesFocus("pocket.toggle_list", []))
    }
}
