import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A key-opened pocket list (#2974 ▸ Ruling 4): a row lifted, the
/// arrows and Return walking it with the chord's ⌘ still held, and
/// its rows speaking, since no menu twins it.
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
        #expect(core.shelves.peek.panel.body.hovered == 0)
        // Closed and reopened, it starts over at the first row.
        let walked = core.shelves.peek.panel
        #expect(walked.morphKey(Self.down))
        core.execute("pocket.toggle_list")
        walked.land(0) {}
        core.execute("pocket.toggle_list")
        #expect(walked.body.hovered == 0)
        // A redraw of the list keeps the row the arrows reached.
        let panel = core.shelves.peek.panel
        #expect(panel.morphKey(Self.down))
        #expect(panel.body.hovered == 1)
        // A pointer nudged off its row leaves the row to Return.
        panel.body.pointerHovers(nil)
        #expect(panel.body.hovered == 1)
        core.shelves.peek.show(
            try #require(core.pocketPlate.view(on: display)),
            source: .pocket(core.pocketPlateWindows),
            space: nil,
            edge: .bottom
        )
        #expect(panel.body.hovered == 1)
        #expect(core.shelves.peek.shown?.keyed == true)
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
        #expect(panel.body.hovered == 1)
        #expect(core.shelves.peek.shown != nil)
        #expect(
            window.performKeyEquivalent(with: key(Self.up, "\u{F700}"))
        )
        #expect(panel.body.hovered == 0)
        var picked: [WindowID] = []
        core.shelves.peek.pick = { id, _ in picked.append(id) }
        #expect(window.performKeyEquivalent(with: key(Self.enter, "\r")))
        #expect(picked == [one])
        core.execute("pocket.toggle_list")
        #expect(window.performKeyEquivalent(with: key(76, "\u{3}")))
        #expect(picked == [one, one])
        core.execute("pocket.toggle_list")
        #expect(window.performKeyEquivalent(with: key(12, "q")))
        #expect(core.shelves.peek.shown == nil)
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

    @Test("a key-opened list speaks; a click's stays the menu's")
    func rowsSpeak() throws {
        let fixture = try PocketListFixture()
        let (core, display) = (fixture.core, fixture.display)
        defer { fixture.tearDown() }
        fixture.pocket([one, two])
        let view = try #require(core.pocketPlate.view(on: display))
        let peek = core.shelves.peek
        core.pocketPlate.onClick(view)
        #expect(peek.panel.panel?.isAccessibilityElement() == false)
        #expect(peek.panel.body.rowButtons.isEmpty)
        peek.dismiss()
        core.execute("pocket.toggle_list")
        #expect(peek.panel.panel?.isAccessibilityElement() == true)
        let body = peek.panel.body
        let buttons = body.rowButtons
        try #require(buttons.count == 2)
        for (button, target) in zip(buttons, body.targets) {
            #expect(button.superview === body)
            #expect(button.frame == target.frame)
            #expect(button.isAccessibilityElement())
            #expect(target.inks.allSatisfy { !$0.isAccessibilityElement() })
        }
        #expect(buttons.allSatisfy { $0.accessibilityRole() == .button })
        #expect(buttons[0].accessibilityLabel() == "Window 1")
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
        #expect(moved == [buttons[1]])
        var picked: [WindowID] = []
        peek.pick = { id, _ in picked.append(id) }
        #expect(buttons[1].accessibilityPerformPress())
        #expect(picked == [two])
        #expect(peek.panel.panel?.isAccessibilityElement() == false)
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
        #expect(moved == [body.rowButtons[0]])
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
        #expect(peek.panel.panel?.isAccessibilityElement() == false)
        #expect(peek.panel.panel?.walksHeldKeys == false)
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
        #expect(body.targets.first?.action == .more)
        body.liftRow(nil)
        let lifted = try #require(body.hovered)
        #expect(lifted > 0)
        // A row past a shrunken list lands on its last.
        body.liftRow(9)
        #expect(body.hovered == body.targets.count - 1)
    }
}
