import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// How a list's peek holds and what closes it (#1946): the hold
/// polls the gap its body's tracking cannot see, re-reads slowly
/// inside the body in case its exit is lost, and a press
/// anywhere in a bar reaches it through the shelf panel's one press
/// point.
@Suite("Bar hover peek hold and press", .serialized)
@MainActor
struct BarPeekHoldTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    /// `+1` stands for one window the chip did not draw: a list by
    /// the one predicate, so its click shows a peek that holds —
    /// one the pointer could never reach otherwise (#1946).
    @Test("A +n peek of one hidden window holds in the hull")
    func overflowOfOneHolds() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        let source = BarPeekSource.overflow([WindowID(7)])
        #expect(source.isList)
        #expect(!BarPeekSource.glyph([WindowID(7)]).isList)
        #expect(!BarPeekSource.appItem([WindowID(7)]).isList)
        rig.peek.show(
            rig.first,
            source: source,
            space: SpaceID("1"),
            edge: .top
        )
        rig.pointer = try rig.gap()
        rig.peek.pointer(
            in: rig.item,
            on: nil,
            source: nil,
            edge: .top
        )
        #expect(rig.shownTitles == ["Window 7"], "held in the gap")
        #expect(rig.peek.holding)
    }

    /// Inside the peek its body's own tracking reports the pointer,
    /// so the hold polls the gap fast and slows inside: entering
    /// slows the poll, leaving into the gap restarts it fast, and
    /// leaving the hull closes the peek on that report.
    @Test("The hold polls the gap fast and the body slowly")
    func holdPollsTheGapFast() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        rig.pointer = try rig.gap()
        rig.hover(nil)
        #expect(rig.steps.count == 1, "polling the gap")
        #expect(rig.dwells.last == BarPeek.Timing.holdPoll)
        let peek = try #require(rig.peek.panel.panel?.frame)
        rig.pointer = CGPoint(x: peek.midX, y: peek.midY)
        rig.peek.panel.body.onPointerInside(true)
        rig.step()
        #expect(rig.steps.count == 1, "a slow re-read inside")
        #expect(rig.dwells.last == BarPeek.Timing.insideRecheck)
        #expect(BarPeek.Timing.insideRecheck > BarPeek.Timing.holdPoll)
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        rig.pointer = try rig.gap()
        rig.peek.panel.body.onPointerInside(false)
        #expect(rig.dwells.last == BarPeek.Timing.holdPoll, "fast again")
        rig.peek.panel.body.onPointerInside(true)
        rig.pointer = CGPoint(x: peek.maxX + 200, y: peek.midY)
        rig.peek.panel.body.onPointerInside(false)
        #expect(rig.peek.panel.drawn == nil, "out of the hull it closes")
    }

    /// A lost exit — a view moved under a resting pointer gets none
    /// (#1665), a press dragged out with the button held — leaves
    /// the body reporting inside; the slow re-read closes the peek
    /// once the pointer is outside the hull.
    @Test("A lost exit heals on the slow re-read")
    func lostExitHeals() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        rig.pointer = try rig.gap()
        rig.hover(nil)
        let peek = try #require(rig.peek.panel.panel?.frame)
        rig.pointer = CGPoint(x: peek.midX, y: peek.midY)
        rig.peek.panel.body.onPointerInside(true)
        rig.step()
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        // The pointer leaves the hull and no exit arrives.
        rig.pointer = CGPoint(x: peek.maxX + 200, y: peek.midY)
        rig.step()
        #expect(rig.peek.panel.drawn == nil, "the re-read closes it")
        #expect(!rig.peek.holding)
    }

    /// The body reports the pointer inside before the item reports
    /// it gone — the pointer crossed straight onto the peek — so the
    /// hold starts already inside: its slow re-read still runs, and
    /// closes the peek once the pointer leaves the hull unreported.
    @Test("A hold that starts inside the body still re-reads")
    func holdStartingInsideReReads() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        let peek = try #require(rig.peek.panel.panel?.frame)
        rig.pointer = CGPoint(x: peek.midX, y: peek.midY)
        rig.peek.panel.body.onPointerInside(true)
        #expect(rig.steps.isEmpty, "not holding yet")
        rig.hover(nil)
        #expect(rig.peek.holding)
        #expect(rig.steps.count == 1, "the hold re-reads")
        #expect(rig.dwells.last == BarPeek.Timing.insideRecheck)
        // The pointer leaves the hull and no exit arrives.
        rig.pointer = CGPoint(x: peek.maxX + 200, y: peek.midY)
        rig.step()
        #expect(rig.peek.panel.drawn == nil, "the re-read closes it")
    }

    /// The body's own enter, delivered as AppKit delivers it, tells
    /// the hold the pointer is inside: the re-read slows.
    @Test("The body's enter reaches the hold")
    func bodyEnterReachesTheHold() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        rig.pointer = try rig.gap()
        rig.hover(nil)
        #expect(rig.dwells.last == BarPeek.Timing.holdPoll)
        let peek = try #require(rig.peek.panel.panel?.frame)
        rig.pointer = CGPoint(x: peek.midX, y: peek.midY)
        let entered = try #require(
            NSEvent.enterExitEvent(
                with: .mouseEntered,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                trackingNumber: 0,
                userData: nil
            )
        )
        rig.peek.panel.body.mouseEntered(with: entered)
        rig.step()
        #expect(rig.steps.count == 1)
        #expect(
            rig.dwells.last == BarPeek.Timing.insideRecheck,
            "the enter slowed the re-read"
        )
    }

    /// The body's tracking area is what reports: its enter and exit
    /// reach the peek's hold.
    @Test("The body's enter and exit reach the hold")
    func bodyTrackingReachesTheHold() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        var reports: [Bool] = []
        let body = BarPeekBody()
        body.onPointerInside = { reports.append($0) }
        let event = try #require(
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
            )
        )
        body.mouseExited(with: event)
        #expect(reports == [false])
        rig.hover(rig.first, 1, 2)
        rig.step()
        rig.pointer = try rig.gap()
        rig.hover(nil)
        rig.peek.panel.body.mouseExited(with: event)
        #expect(rig.steps.count == 2, "the exit re-reads the gap")
    }

    // MARK: - A press in a bar

    /// `ShelfPanel` hands every press in a bar to the peek: it
    /// closes, save a left press on a Space Bar glyph, whose
    /// release decides — another button's press there closes it.
    @Test("A press in a bar closes the peek, save a left one on a glyph")
    func pressInABarCloses() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        let glyph = SpaceBarGlyphTarget(
            space: SpaceID("1"),
            windows: [WindowID(1), WindowID(2)],
            kind: .glyph,
            label: "App"
        )
        rig.peek.pressed(on: glyph, type: .leftMouseDown)
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        rig.peek.pressed(on: NSView(), type: .leftMouseDown)
        #expect(rig.peek.panel.drawn == nil)
        rig.hover(rig.first, 1, 2)
        #expect(rig.dwells.count == 1, "shut until the pointer leaves")
    }

    /// Only a left press on a glyph waits for its release: a
    /// middle (other) button's press there closes the peek.
    @Test("An other-button press on a glyph closes the peek")
    func otherPressOnAGlyphCloses() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        rig.hover(rig.first, 1, 2)
        rig.step()
        #expect(rig.shownTitles == ["Window 1", "Window 2"])
        let glyph = SpaceBarGlyphTarget(
            space: SpaceID("1"),
            windows: [WindowID(1), WindowID(2)],
            kind: .glyph,
            label: "App"
        )
        rig.peek.pressed(on: glyph, type: .otherMouseDown)
        #expect(rig.peek.panel.drawn == nil, "a middle press closes")
    }

    /// The panel's own `sendEvent` reports each press, with the
    /// view it hits, ahead of that view — and nothing else.
    @Test("The shelf panel reports every press with its hit view")
    func shelfPanelReportsPresses() throws {
        let panel = BarPanel.configure(
            ShelfPanel(
                contentRect: CGRect(x: 0, y: 0, width: 100, height: 30),
                styleMask: BarPanel.styleMask,
                backing: .buffered,
                defer: false
            )
        )
        defer { panel.orderOut(nil) }
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
        let count = NSView(frame: CGRect(x: 60, y: 0, width: 40, height: 30))
        content.addSubview(count)
        panel.contentView = content
        var hits: [NSView?] = []
        var types: [NSEvent.EventType] = []
        panel.onPress = {
            hits.append($0)
            types.append($1)
        }
        for type: NSEvent.EventType in [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .otherMouseDown,
            .mouseMoved,
        ] {
            let event = try #require(
                NSEvent.mouseEvent(
                    with: type,
                    location: CGPoint(x: 80, y: 15),
                    modifierFlags: [],
                    timestamp: 0,
                    windowNumber: panel.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                )
            )
            panel.sendEvent(event)
        }
        #expect(hits.count == 3, "the three presses, nothing else")
        #expect(hits.allSatisfy { $0 === count })
        #expect(
            types == [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            "each press carries its own type"
        )
    }
}
