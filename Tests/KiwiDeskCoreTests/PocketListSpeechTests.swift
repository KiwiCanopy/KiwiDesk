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

/// A key-opened pocket list speaks, since no menu twins it (#2974):
/// one button per row, VoiceOver's cursor on the lifted row; and that
/// state stays on that list, off every other show of the one panel.
@Suite(
    "A key-opened pocket list speaks",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketListSpeechTests {
    private let one = WindowID(1)
    private let two = WindowID(2)
    private static let down: UInt16 = 125

    @Test("a key-opened list speaks; a click's stays the menu's")
    func rowsSpeak() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let view = try #require(core.pocketPlate.view(on: display))
        let peek = core.shelves.peek
        core.pocketPlate.onClick(view)
        expectEqual(peek.panel.panel?.isAccessibilityElement(), false)
        #expect(peek.panel.body.rowButtons.isEmpty)
        peek.dismiss()
        core.execute("pocket.toggle_list")
        expectEqual(peek.panel.panel?.isAccessibilityElement(), true)
        let body = peek.panel.body
        let buttons = body.rowButtons
        try #require(buttons.count == 2)
        for (button, target) in zip(buttons, body.targets) {
            #expect(button.superview === body)
            expectEqual(button.frame, target.frame)
            #expect(button.isAccessibilityElement())
            #expect(target.inks.allSatisfy { !$0.isAccessibilityElement() })
        }
        #expect(buttons.allSatisfy { $0.accessibilityRole() == .button })
        expectEqual(buttons[0].accessibilityLabel(), "Window 1")
        #expect(
            BarPeekBody.spokenRow(
                .init(
                    window: one,
                    title: "Notes",
                    chord: "⌃⌥N",
                    spokenChord: "Control Option N"
                )
            ) == "Notes, Control Option N"
        )
        var moved: [NSView] = []
        body.moveVoiceOver = { moved.append($0) }
        #expect(peek.panel.morphKey(Self.down))
        expectEqual(moved, [buttons[1]])
        var picked: [WindowID] = []
        peek.pick = { id, _ in picked.append(id) }
        #expect(buttons[1].accessibilityPerformPress())
        expectEqual(picked, [two])
        expectEqual(peek.panel.panel?.isAccessibilityElement(), false)
    }

    @Test("an app's own row speaks its key in words")
    func keyedRowSpeaksItsKey() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one])
        core.state.pocket = core.state.pocket.map {
            var slot = $0
            slot.keyedApp = "com.example.app"
            return slot
        }
        core.barMenuHooks.pocketKeyChord = { _ in
            RenderedChord(drawn: "⌃⌥T", spoken: "Control Option T")
        }
        core.execute("pocket.toggle_list")
        #expect(
            core.shelves.peek.panel.body.rowButtons.last?.accessibilityLabel()
                == "Window 1, Control Option T"
        )
    }

    @Test("another anchor's list is no key's, a keyed one open or not")
    func otherAnchorIsNotKeyed() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one])
        core.execute("pocket.toggle_list")
        let host = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 40, height: 40),
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )
        defer { host.orderOut(nil) }
        let other = PocketPlateView(frame: host.contentLayoutRect)
        host.contentView = other
        host.orderFrontRegardless()
        core.shelves.peek.shelf = { _ in KiwiShelf() }
        core.shelves.peek.show(
            other,
            source: .pocket(core.pocketPlateWindows),
            space: nil,
            edge: .bottom
        )
        #expect(core.shelves.peek.shown?.view === other)
        expectEqual(core.shelves.peek.shown?.keyed, false)
        #expect(core.shelves.peek.panel.body.rowButtons.isEmpty)
    }

    /// Its plate speaks a count and opens a menu of what the list holds,
    /// one's own window under One window included.
    @Test("under One window VoiceOver's press menus an app's own window")
    func pressMenusKeyedWindow() throws {
        LocalizationManager.shared.select("en")
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        fixture.pocket([one])
        core.state.pocket = core.state.pocket.map {
            var slot = $0
            slot.keyedApp = "com.example.app"
            return slot
        }
        core.execute("pocket.set_capacity", args: [.string("one")])
        core.pocketPlate.dragging = one
        core.updatePocketPlate(slots: [:])
        var asked: [BarPeekSource] = []
        core.shelves.peek.openMenu = { source, _, _ in asked.append(source) }
        let view = try #require(core.pocketPlate.view(on: display))
        expectEqual(view.accessibilityLabel(), "Pocket, windows inside: 1")
        #expect(view.accessibilityPerformPress())
        expectEqual(asked, [.pocket([one])])
        #expect(core.shelves.peek.shown == nil)
    }

    @Test("a key-opened list's cursor lands on its first row")
    func openMovesVoiceOver() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let body = core.shelves.peek.panel.body
        var moved: [NSView] = []
        body.moveVoiceOver = { moved.append($0) }
        core.execute("pocket.toggle_list")
        expectEqual(moved, [body.rowButtons[0]])
    }

    /// The panel is one: every other show door takes the keyed state
    /// off, or a hover label would speak.
    @Test("a later hover peek or pill list on the panel stays hidden")
    func otherShowsResetKeyed() throws {
        let fixture = try PocketListFixture()
        let core = fixture.core
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let peek = core.shelves.peek
        core.execute("pocket.toggle_list")
        let content = try #require(peek.panel.drawn)
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)
        peek.panel.show(
            content,
            shelf: KiwiShelf(),
            edge: .bottom,
            anchor: frame,
            strip: frame,
            visible: frame,
            fades: false
        )
        #expect(!peek.panel.body.keyed)
        #expect(peek.panel.body.rowButtons.isEmpty)
        expectEqual(peek.panel.panel?.isAccessibilityElement(), false)
        expectEqual(peek.panel.panel?.walksHeldKeys, false)
        // The pill's list, the other door.
        peek.dismiss()
        core.execute("pocket.toggle_list")
        #expect(peek.panel.body.keyed)
        let pill = PillAnchor(frame: frame)
        peek.panel.showMorph(
            content,
            shelf: KiwiShelf(),
            request: .init(anchor: pill, pill: frame, edge: .bottom),
            visible: frame
        )
        #expect(!peek.panel.body.keyed)
        #expect(peek.panel.body.rowButtons.isEmpty)
        expectEqual(peek.panel.panel?.isAccessibilityElement(), false)
        expectEqual(peek.panel.panel?.walksHeldKeys, false)
    }
}

/// A pill a list grows out of, on no panel.
@MainActor
private final class PillAnchor: NSView, BarPeekMorphAnchor {
    var morphRoom: CGRect { frame }
    var morphText: String { "+2" }
    var placedScreenFrame: CGRect? { frame }
    func setMorphed(_ morphed: Bool, pointer: CGPoint) {}
}
