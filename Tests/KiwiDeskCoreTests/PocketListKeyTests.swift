import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `pocket.toggle_list` (#2974 ▸ Ruling): a key opens the pocket's list
/// wherever the pocket is, a row lifted, and picks a window by
/// keyboard; no bar moves, a stand-down refuses, and the rows speak.
@Suite(
    "The pocket's list by key",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketListKeyTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private static let down: UInt16 = 125
    private static let up: UInt16 = 126
    private static let enter: UInt16 = 36
    private static let escape: UInt16 = 53

    /// One window by default, two windows tracked; the Space Bar at the
    /// top, so the pocket's own edge draws nothing.
    private func makeCore() throws -> (KiwiCore, DisplayID) {
        let core = makeTestCore(
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
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
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
        return (core, id)
    }

    private func tearDown(_ core: KiwiCore) {
        core.shelves.peek.dismiss()
        core.shelves.peek.panel.panel?.orderOut(nil)
        core.pocketPlate.sync([])
        NativeSpaces.currentSpaceIsUserOverride = nil
    }

    /// Pockets `ids`, Several windows holding them.
    private func pocket(_ ids: [WindowID], in core: KiwiCore) {
        core.execute("pocket.set_capacity", args: [.string("several")])
        for id in ids {
            core.handle(.windowFocused(id))
            core.execute("toggle_pocket_window")
            core.execute("pocket")
            #expect(core.state.isPocketed(id))
        }
    }

    @Test("under One window the key stands the pocket and closes it again")
    func oneWindowStandsAndCloses() throws {
        let (core, display) = try makeCore()
        defer { tearDown(core) }
        core.updateBars()
        #expect(!core.pocketStands)
        let held = core.shelfReservations
        #expect(core.execute("pocket.toggle_list").error == nil)
        let view = try #require(core.pocketPlate.view(on: display))
        #expect(core.shelves.peek.shown?.view === view)
        #expect(core.pocketListDisplay == display)
        #expect(core.pocketStands)
        // The bars' plan stays capacity-only: no slot, no reservation.
        #expect(core.pocketPlate.slots[display] == nil)
        #expect(core.shelfReservations == held)
        #expect(core.execute("pocket.toggle_list").error == nil)
        #expect(core.shelves.peek.shown == nil)
        #expect(!core.pocketStands)
        #expect(core.pocketPlate.specs[display] == nil)
    }

    /// A setter's dispatch ends in a forced pass, which drops learned
    /// bounds and re-laid a tiled Space on every press (device).
    @Test("opening and closing the list runs no layout pass")
    func runsNoPass() throws {
        let (core, _) = try makeCore()
        defer { tearDown(core) }
        let meter = WorkMeter(now: { 0 })
        core.tiler.meter = meter
        #expect(core.execute("pocket.toggle_list").isSuccess)
        #expect(core.shelves.peek.shown != nil)
        #expect(core.execute("pocket.toggle_list").isSuccess)
        let counts = meter.snapshot(reset: false).counts
        #expect(counts.retiles + counts.passesHeld == 0)
    }

    @Test("a handle's pocket rises for the key's list and sinks after it")
    func handleRises() throws {
        let (core, display) = try makeCore()
        defer { tearDown(core) }
        pocket([one], in: core)
        core.updatePocketPlate(slots: [:])
        #expect(core.pocketPlate.specs[display]?.risen == false)
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        #expect(core.pocketPlate.specs[display]?.risen == true)
        core.execute("pocket.toggle_list")
        #expect(core.pocketPlate.specs[display]?.risen == false)
    }

    @Test("the key lifts the first row; a click lifts none")
    func keyLiftsTheFirstRow() throws {
        let (core, display) = try makeCore()
        defer { tearDown(core) }
        pocket([one, two], in: core)
        core.updatePocketPlate(slots: [:])
        let view = try #require(core.pocketPlate.view(on: display))
        core.pocketPlate.onClick(view)
        #expect(core.shelves.peek.panel.body.hovered == nil)
        core.execute("pocket.toggle_list")
        #expect(core.shelves.peek.shown == nil)
        core.execute("pocket.toggle_list")
        #expect(core.shelves.peek.panel.body.hovered == 0)
        // A redraw of the list keeps the row the arrows reached.
        let panel = core.shelves.peek.panel
        #expect(panel.morphKey(Self.down))
        #expect(panel.body.hovered == 1)
        core.shelves.peek.show(
            try #require(core.pocketPlate.view(on: display)),
            source: .pocket(core.pocketPlateWindows),
            space: nil,
            edge: .bottom,
            keyed: true
        )
        #expect(panel.body.hovered == 1)
    }

    @Test("the arrows walk the rows, Return picks, Esc closes")
    func keysWalkAndPick() throws {
        let (core, _) = try makeCore()
        defer { tearDown(core) }
        pocket([one, two], in: core)
        core.updatePocketPlate(slots: [:])
        core.execute("pocket.toggle_list")
        var picked: [WindowID] = []
        core.shelves.peek.pick = { id, _ in picked.append(id) }
        let panel = core.shelves.peek.panel
        #expect(panel.morphKey(Self.down))
        #expect(panel.morphKey(Self.up))
        #expect(panel.body.hovered == 0)
        #expect(panel.morphKey(Self.down))
        #expect(panel.morphKey(Self.enter))
        #expect(picked == [two])
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
        let (core, _) = try makeCore()
        defer { tearDown(core) }
        pocket([one, two], in: core)
        core.updatePocketPlate(slots: [:])
        core.execute("pocket.toggle_list")
        let panel = core.shelves.peek.panel
        let window = try #require(panel.panel)
        #expect(
            window.performKeyEquivalent(with: key(Self.down, "\u{F701}"))
        )
        #expect(panel.body.hovered == 1)
        #expect(core.shelves.peek.shown != nil)
        #expect(window.performKeyEquivalent(with: key(12, "q")))
        #expect(core.shelves.peek.shown == nil)
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

    @Test("an empty pocket shows its empty state, its first row lifted")
    func emptyShowsItsState() throws {
        let (core, _) = try makeCore()
        defer { tearDown(core) }
        core.execute("pocket.toggle_list")
        let panel = core.shelves.peek.panel
        #expect(panel.drawn?.empty != nil)
        #expect(panel.body.hovered == 0)
    }

    @Test("a stand-down refuses with no list and no pocket")
    func standDownRefuses() throws {
        let (core, display) = try makeCore()
        defer { tearDown(core) }
        NativeSpaces.currentSpaceIsUserOverride = { _ in false }
        #expect(
            core.execute("pocket.toggle_list").error
                == "the pocket stays hidden while a window fills the screen"
        )
        #expect(core.shelves.peek.shown == nil)
        #expect(core.pocketPlate.specs[display] == nil)
        #expect(core.pocketPlate.openingList == nil)
    }

    @Test("a list that cannot open leaves no pocket standing for it")
    func failedOpenLeavesNothing() throws {
        let (core, display) = try makeCore()
        defer { tearDown(core) }
        core.shelves.peek.content = { _, _ in nil }
        #expect(core.execute("pocket.toggle_list").error != nil)
        #expect(core.pocketPlate.openingList == nil)
        #expect(!core.pocketStands)
        #expect(core.pocketPlate.specs[display] == nil)
    }

    /// The list closing inside a sync: that sync's specs were read with
    /// the list holding the pocket.
    @Test("a list a change closes takes its One-window pocket with it")
    func closedListLeavesInTheSamePass() throws {
        let (core, display) = try makeCore()
        defer { tearDown(core) }
        core.handle(.windowFocused(one))
        core.execute("toggle_pocket_window")
        core.execute("pocket")
        #expect(core.state.isPocketed(one))
        core.execute("pocket.toggle_list")
        #expect(core.pocketListDisplay == display)
        core.state.apply(.windowDestroyed(one, wasMinimized: false))
        core.updatePocketPlate()
        #expect(core.shelves.peek.shown == nil)
        #expect(core.pocketPlate.specs[display] == nil)
    }

    @Test("a key-opened list speaks; a click's stays the menu's")
    func rowsSpeak() throws {
        let (core, display) = try makeCore()
        defer { tearDown(core) }
        pocket([one, two], in: core)
        core.updatePocketPlate(slots: [:])
        let view = try #require(core.pocketPlate.view(on: display))
        let peek = core.shelves.peek
        core.pocketPlate.onClick(view)
        #expect(peek.panel.panel?.isAccessibilityElement() == false)
        #expect(peek.panel.body.rowButtons.isEmpty)
        peek.dismiss()
        core.execute("pocket.toggle_list")
        #expect(peek.panel.panel?.isAccessibilityElement() == true)
        let buttons = peek.panel.body.rowButtons
        #expect(buttons.count == 2)
        #expect(buttons.allSatisfy { $0.accessibilityRole() == .button })
        #expect(buttons[0].accessibilityLabel() == "Window 1")
        var picked: [WindowID] = []
        peek.pick = { id, _ in picked.append(id) }
        #expect(buttons[1].accessibilityPerformPress())
        #expect(picked == [two])
        #expect(peek.panel.panel?.isAccessibilityElement() == false)
    }

    @Test("it acts on no window: out of the foreground preflight")
    func noFocusImplied() throws {
        let (core, _) = try makeCore()
        defer { tearDown(core) }
        #expect(!core.impliesFocus("pocket.toggle_list", []))
    }
}
