import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A Desktops click is ↩ on what it lands on (#3209): a line goes to
/// its Space, an icon to its window, a title to its Desktop, and a
/// carry drops; ⇧, ⌥ and ⌘ keep their picks, and a double click's
/// second press acts on nothing. The overview is
/// `DesktopsStateTests.overview()`: screen 1 is KiwiHub's.
@MainActor
@Suite("Desktops clicks act as Return")
struct DesktopsClickTests {
    private final class Box { var actions: [DesktopsAction] = [] }

    private func model(_ box: Box) -> JumpModel {
        let model = JumpModel(
            snapshot: JumpSnapshot(entries: [], here: nil, hereIcon: nil),
            icons: [:],
            rowCap: 6
        )
        model.loadDesktops = { DesktopsStateTests.overview() }
        model.onDesktopsAction = { box.actions.append($0) }
        model.setScope(.desktops)
        return model
    }

    private let line = DesktopsPlace(screen: 1, desktop: 1, line: 0)
    private let first = DesktopsPlace(screen: 1, desktop: 0, line: 0)

    @Test("a line click goes to its Space; a second press does nothing")
    func lineJumps() throws {
        let box = Box()
        let model = model(box)
        model.clickPlace(line, count: 1, modifiers: [], opens: true)
        let target = try #require(model.desktops?.target(line))
        #expect(box.actions == [.jump(target)])
        model.clickPlace(line, count: 2, modifiers: [], opens: true)
        #expect(box.actions.count == 1)
    }

    @Test("a title click goes to its Desktop")
    func titleJumpsToTheDesktop() throws {
        let box = Box()
        let model = model(box)
        model.clickPlace(line, count: 1, modifiers: [], opens: false)
        let desktop = try #require(model.desktops?.desktop(line))
        #expect(box.actions == [.jumpDesktop(desktop)])
    }

    @Test("an icon click jumps to its window; a second press does nothing")
    func iconJumps() {
        let box = Box()
        let model = model(box)
        model.clickWindow(WindowID(3), in: first, count: 1, modifiers: [])
        #expect(box.actions == [.jumpWindow(WindowID(3))])
        model.clickWindow(WindowID(3), in: first, count: 2, modifiers: [])
        #expect(box.actions.count == 1)
    }

    @Test("⇧ moves, ⌥ swaps, ⌘ picks up and a plain click then drops")
    func modifiersKeepTheirPicks() throws {
        let box = Box()
        let model = model(box)
        model.clickPlace(line, count: 1, modifiers: .shift, opens: true)
        let target = try #require(model.desktops?.target(line))
        #expect(box.actions == [.moveYours(target, follow: false)])
        model.clickWindow(
            WindowID(4),
            in: first,
            count: 1,
            modifiers: .option
        )
        #expect(box.actions.last == .swapWindowHere(WindowID(4)))
        box.actions = []
        model.clickWindow(
            WindowID(5),
            in: first,
            count: 1,
            modifiers: .command
        )
        #expect(model.desktops?.carried == [WindowID(5)])
        #expect(box.actions.isEmpty)
        // A plain click while carrying drops, on an icon's line too.
        model.clickWindow(WindowID(20), in: line, count: 1, modifiers: [])
        #expect(box.actions == [.drop([WindowID(5)], target, follow: false)])
    }

    @Test("⌥ and ⌘ on a place pick nothing, as ⌥↩ and ⌘↩ there do")
    func placeIgnoresWindowModifiers() {
        let box = Box()
        let model = model(box)
        model.clickPlace(line, count: 1, modifiers: .option, opens: true)
        model.clickPlace(line, count: 1, modifiers: .command, opens: true)
        #expect(box.actions.isEmpty)
        #expect(model.desktops?.place == line)
    }

    @Test("⌥ and ⌘ on a place, and ⌥ on an icon, drop no carry")
    func carryIgnoresWindowModifiers() {
        let box = Box()
        let model = model(box)
        model.clickWindow(
            WindowID(5),
            in: first,
            count: 1,
            modifiers: .command
        )
        model.clickPlace(line, count: 1, modifiers: .option, opens: true)
        model.clickPlace(line, count: 1, modifiers: .command, opens: true)
        model.clickWindow(
            WindowID(20),
            in: line,
            count: 1,
            modifiers: .option
        )
        #expect(box.actions.isEmpty)
        #expect(model.desktops?.carried == [WindowID(5)])
    }

    @Test("an icon on another line takes no lift on a still pointer")
    func strangerIconNeedsAMove() {
        let model = model(Box())
        let point = CGPoint(x: 1, y: 1)
        model.currentPointer = { point }
        model.hoverDesktops(.place(line), pointer: point)
        #expect(model.hover == .place(line))
        // Window 3 sits on `first`, not on the lifted line.
        model.hoverDesktops(.window(WindowID(3)), pointer: point)
        #expect(model.hover == nil)
    }

    @Test("a close a click on the panel made holds for the double click")
    func clickHoldLastsTheInterval() throws {
        let up = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: .zero,
                modifierFlags: [],
                timestamp: 100,
                windowNumber: 42,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 0
            )
        )
        func hold(_ event: NSEvent?, on window: Int?, at now: Double)
            -> Double
        {
            PanelPresence.clickHold(
                after: event,
                on: window,
                now: now,
                interval: 0.5
            )
        }
        #expect(abs(hold(up, on: 42, at: 100.1) - 0.4) < 0.0001)
        #expect(hold(up, on: 42, at: 101) == 0)
        // A release on another window, or none, made no close.
        #expect(hold(up, on: 7, at: 100.1) == 0)
        #expect(hold(up, on: nil, at: 100.1) == 0)
        let key = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 100,
                windowNumber: 42,
                context: nil,
                characters: "\r",
                charactersIgnoringModifiers: "\r",
                isARepeat: false,
                keyCode: 36
            )
        )
        #expect(hold(key, on: 42, at: 100) == 0)
        #expect(hold(nil, on: 42, at: 100) == 0)
    }

    @Test("an icon keeps the lift over its own line")
    func iconLiftWinsOverItsLine() {
        let model = model(Box())
        var point = CGPoint(x: 1, y: 1)
        model.currentPointer = { point }
        model.hoverDesktops(.place(first), pointer: point)
        #expect(model.hover == .place(first))
        // One move reaches the line first, then its icon.
        point = CGPoint(x: 2, y: 2)
        model.hoverDesktops(.place(first), pointer: point)
        model.hoverDesktops(.window(WindowID(2)), pointer: point)
        #expect(model.hover == .window(WindowID(2)))
        point = CGPoint(x: 3, y: 3)
        model.hoverDesktops(.window(WindowID(2)), pointer: point)
        model.hoverDesktops(.place(first), pointer: point)
        #expect(model.hover == .window(WindowID(2)))
        model.endHover(.window(WindowID(2)))
        point = CGPoint(x: 4, y: 4)
        model.hoverDesktops(.place(first), pointer: point)
        #expect(model.hover == .place(first))
        let title = JumpHover.desktop(screen: 1, index: 0)
        point = CGPoint(x: 5, y: 5)
        model.hoverDesktops(title, pointer: point)
        #expect(model.hover == title)
    }
}
