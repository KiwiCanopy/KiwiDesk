import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The actionable peek (#1946, owner ruling amendment 2): a list's
/// peek holds while the pointer is inside its hull, a click shows it
/// at once or closes it, and its rows pick on a release inside them
/// — a drag off one cancelling — while "N more" opens the menu.
@Suite("Bar hover peek actions", .serialized)
@MainActor
struct BarPeekActionTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    // MARK: - The hull

    @Test("Leaving the item for the hull holds the peek until it leaves")
    func hullHoldsThePeek() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        rig.pointer = try rig.gap()
        rig.hover(nil)
        #expect(
            rig.shownTitles == ["Window 1", "Window 2"],
            "held in the gap"
        )
        #expect(rig.peek.holding)
        #expect(rig.dwells.last == BarPeek.Timing.holdPoll)
        rig.step()
        #expect(
            rig.shownTitles == ["Window 1", "Window 2"],
            "still in the hull"
        )
        let peek = try #require(rig.peek.panel.panel?.frame)
        rig.pointer = CGPoint(x: peek.midX, y: peek.midY)
        rig.step()
        #expect(
            rig.shownTitles == ["Window 1", "Window 2"],
            "on the peek itself"
        )
        rig.pointer = CGPoint(x: peek.maxX + 200, y: peek.midY)
        rig.step()
        #expect(rig.peek.panel.drawn == nil, "out of the hull it closes")
        #expect(!rig.peek.holding)
    }

    @Test("Leaving the item away from the peek closes it at once")
    func outsideTheHullCloses() {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        rig.hover(nil)
        #expect(rig.peek.panel.drawn == nil)
        #expect(!rig.peek.holding)
    }

    /// Crossing the gap may cross a neighbour's report; inside the
    /// hull it does not take the peek, while a pointer resting on
    /// the neighbour itself — outside the hull — swaps at once.
    @Test("A neighbour inside the hull holds; on its own rect it swaps")
    func neighbourSwapOnlyOutsideTheHull() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 3)
        rig.step()
        rig.pointer = try rig.gap()
        rig.hover(rig.second, 2)
        #expect(
            rig.shownTitles == ["Window 1", "Window 3"],
            "the swap is held"
        )
        let neighbour = rig.screen(rig.second)
        rig.pointer = CGPoint(x: neighbour.midX, y: neighbour.midY)
        rig.hover(rig.second, 2)
        #expect(rig.shownTitles == ["Window 2"], "the bar still swaps")
    }

    /// A one-window peek has no row worth reaching for, so it never
    /// holds: it closes as the pointer leaves its item (#1946).
    @Test("A one-window peek closes in the gap; only a list holds")
    func oneWindowPeekNeverHolds() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        rig.pointer = try rig.gap()
        #expect(!rig.peek.holdsPointer)
        rig.hover(nil)
        #expect(rig.peek.panel.drawn == nil)
        #expect(!rig.peek.holding)
    }

    // MARK: - The toggle

    @Test("A click shows the peek at once, with no dwell")
    func clickTogglesAtOnce() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.peek.toggle(
            rig.first,
            source: .glyph([WindowID(1), WindowID(2)]),
            space: SpaceID("1"),
            edge: .top
        )
        #expect(rig.dwells.isEmpty, "no dwell")
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        // A list's peek: it holds in the hull, as a hover's does.
        rig.pointer = try rig.gap()
        rig.hover(nil)
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        #expect(rig.peek.holding)
        // Leaving the hull closes it.
        rig.pointer = CGPoint(x: -1e6, y: -1e6)
        rig.step()
        #expect(rig.peek.panel.drawn == nil)
    }

    @Test("A click on an item whose hover peek shows closes it")
    func clickClosesAHoverPeek() {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        rig.peek.toggle(
            rig.first,
            source: .glyph([WindowID(1), WindowID(2)]),
            space: SpaceID("1"),
            edge: .top
        )
        #expect(rig.peek.panel.drawn == nil, "the click closes it")
        rig.hover(rig.first, 1, 2)
        rig.step()
        #expect(rig.dwells.count == 1, "shut until the pointer leaves")
        // A dismissal, not a fade: no cool-down re-shows it at once.
        #expect(rig.shownTitles == nil)
    }

    @Test("A second click on the toggled item closes its peek")
    func secondClickCloses() {
        let rig = BarPeekRig()
        defer { rig.close() }
        let source = BarPeekSource.glyph([WindowID(1), WindowID(2)])
        for _ in 0..<2 {
            rig.peek.toggle(
                rig.first,
                source: source,
                space: SpaceID("1"),
                edge: .top
            )
        }
        #expect(rig.peek.panel.drawn == nil, "the second click closes")
        rig.hover(rig.first, 1, 2)
        rig.step()
        #expect(rig.dwells.isEmpty, "shut until the pointer leaves")
        // A dismissal, not a fade: no cool-down re-shows it at once.
        #expect(rig.shownTitles == nil)
    }

    // MARK: - The rows

    /// A left mouse event at `point` in `body`'s own coordinates,
    /// delivered through its window.
    private func send(
        _ type: NSEvent.EventType,
        at point: CGPoint,
        to body: BarPeekBody
    ) throws {
        let window = try #require(body.window)
        let event = try #require(
            NSEvent.mouseEvent(
                with: type,
                location: body.convert(point, to: nil),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        switch type {
        case .leftMouseDown: body.mouseDown(with: event)
        case .leftMouseDragged: body.mouseDragged(with: event)
        default: body.mouseUp(with: event)
        }
    }

    private func centre(_ frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    @Test("A release inside a row picks its window and closes the peek")
    func releaseInsideRowPicks() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        let body = rig.peek.panel.body
        #expect(
            body.targets.map(\.action) == [
                .window(WindowID(1)), .window(WindowID(2)),
            ]
        )
        let second = centre(body.targets[1].frame)
        try send(.leftMouseDown, at: second, to: body)
        #expect(rig.picks.isEmpty, "the press does not pick")
        try send(.leftMouseUp, at: second, to: body)
        #expect(rig.picks.map(\.0) == [WindowID(2)])
        #expect(rig.picks.map(\.1) == [SpaceID("1")], "the chip's Space")
        #expect(rig.peek.panel.drawn == nil, "a pick closes the peek")
    }

    /// A closing peek still fades on screen: it takes no click, and
    /// a row reached anyway picks nothing, never a Space-less focus.
    @Test("A fading peek's rows pick nothing")
    func fadingPeekPicksNothing() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        rig.hover(nil)
        let panel = try #require(rig.peek.panel.panel)
        #expect(panel.ignoresMouseEvents)
        rig.peek.panel.body.onPick(WindowID(1))
        #expect(rig.picks.isEmpty)
    }

    @Test("Dragging off a pressed row cancels its pick")
    func dragOffCancels() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        let body = rig.peek.panel.body
        let first = centre(body.targets[0].frame)
        let other = centre(body.targets[1].frame)
        try send(.leftMouseDown, at: first, to: body)
        try send(.leftMouseDragged, at: other, to: body)
        #expect(body.hovered == nil, "the armed row dims off it")
        try send(.leftMouseUp, at: other, to: body)
        let off = CGPoint(x: -50, y: -50)
        try send(.leftMouseDown, at: first, to: body)
        try send(.leftMouseUp, at: off, to: body)
        #expect(rig.picks.isEmpty)
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
    }

    /// The row under the pointer wears the shelf's own item hover,
    /// its fill and its ink, and gives them back when it leaves. The
    /// shelf's hover ink differs from its resting ink, which the
    /// default shelf's does not, so both halves of the ink can red.
    @Test("The hovered row takes the shelf's item hover")
    func hoveredRowTakesTheShelfHover() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        var shelf = KiwiShelf()
        shelf.itemColor = "#EAF3EE"
        shelf.hoverItemColor = "#102030"
        rig.peek.shelf = { _ in shelf }
        rig.hover(rig.first, 1, 2)
        rig.step()
        let body = rig.peek.panel.body
        let label = try #require(body.targets[1].inks.first as? NSTextField)
        #expect(label.textColor == NSColor(kiwiHex: shelf.itemColor))
        body.setHovered(1)
        #expect(!body.highlight.isHidden)
        #expect(body.highlight.frame == body.targets[1].frame)
        #expect(
            body.highlight.layer?.backgroundColor
                == NSColor(kiwiHex: shelf.hoverFillColor).cgColor
        )
        #expect(label.textColor == NSColor(kiwiHex: shelf.hoverItemColor))
        body.setHovered(nil)
        #expect(body.highlight.isHidden)
        #expect(label.textColor == NSColor(kiwiHex: shelf.itemColor))
    }

    /// "N more" is the menu's button: its release opens the menu of
    /// every window the peek stands for, at the anchor.
    @Test("N more opens the full menu")
    func moreOpensTheMenu() throws {
        LocalizationManager.shared.select("en")
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        let body = BarPeekBody()
        var opened = 0
        body.onMore = { opened += 1 }
        let ids = (1...30).map { WindowID(UInt32($0)) }
        let content = try #require(rig.peek.content(.glyph(ids), nil))
        _ = body.build(content, shelf: KiwiShelf(), maxHeight: 120)
        let more = try #require(
            body.targets.firstIndex { $0.action == .more }
        )
        let point = centre(body.targets[more].frame)
        body.press(at: point)
        body.release(at: point)
        #expect(opened == 1)
        // The shown peek's own button reaches its menu.
        rig.peek.panel.body.onMore()
        #expect(rig.menusOpened == [.glyph([WindowID(1), WindowID(2)])])
    }
}
