import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The hover peek's timing (#1946, the owner's ruling): a dwell
/// before the first show, an instant swap while one shows, a
/// cool-down after, and a press or a moved item closing it until
/// the pointer leaves. The value is `BarPeekContentTests`'.
@Suite("Bar hover peek", .serialized)
@MainActor
struct BarPeekTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    // MARK: - Timing

    /// A host window with two anchors in one reporter, and a peek
    /// whose dwell is stepped by hand.
    @MainActor
    private final class Rig {
        let peek = BarPeek()
        let window = NSPanel(
            contentRect: CGRect(x: 200, y: 800, width: 400, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let item = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        let first = NSView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        let second = NSView(frame: CGRect(x: 40, y: 10, width: 20, height: 20))
        var steps: [@MainActor () -> Void] = []
        var dwells: [TimeInterval] = []
        var clock: TimeInterval = 100

        init() {
            window.contentView?.addSubview(item)
            item.addSubview(first)
            item.addSubview(second)
            window.orderFrontRegardless()
            peek.content = { source in
                BarPeekContent(
                    rows: source.windows.map {
                        BarWindowRow(
                            window: $0,
                            pid: 1,
                            app: "App",
                            title: "Window \($0.raw)",
                            icon: nil
                        )
                    }
                )
            }
            peek.schedule = { [unowned self] delay, body in
                dwells.append(delay)
                steps.append(body)
            }
            peek.now = { [unowned self] in clock }
            peek.shelf = { _ in KiwiShelf() }
        }

        func hover(_ anchor: NSView?, _ id: UInt32 = 1) {
            peek.pointer(
                in: item,
                on: anchor,
                source: anchor.map { _ in .glyph([WindowID(id)]) },
                edge: .top
            )
        }

        func step() {
            let pending = steps
            steps = []
            pending.forEach { $0() }
        }

        var shownTitles: [String]? {
            peek.panel.drawn?.groups.flatMap(\.titles)
        }

        func close() {
            peek.dismiss()
            peek.panel.panel?.orderOut(nil)
            window.orderOut(nil)
        }
    }

    @Test("A first peek waits out the dwell, then shows")
    func dwellThenShow() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        #expect(rig.dwells == [BarPeek.Timing.dwell])
        #expect(rig.peek.panel.drawn == nil)
        rig.step()
        #expect(rig.shownTitles == ["Window 1"])
        #expect(rig.peek.panel.isShown)
    }

    @Test("A pointer that leaves inside the dwell shows nothing")
    func leaveInsideDwell() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.hover(nil)
        rig.step()
        #expect(rig.peek.panel.drawn == nil)
    }

    @Test("While a peek shows, the next item swaps in at once")
    func swapIsInstant() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        rig.hover(rig.second, 2)
        // No second dwell: the swap is immediate.
        #expect(rig.dwells.count == 1)
        #expect(rig.shownTitles == ["Window 2"])
        #expect(rig.peek.shown?.view === rig.second)
    }

    @Test("Leaving closes; inside the cool-down the next shows at once")
    func coolDown() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        #expect(rig.shownTitles == ["Window 1"], "was shown")
        rig.hover(nil)
        #expect(rig.peek.panel.drawn == nil)
        rig.clock += BarPeek.Timing.coolDown / 2
        rig.hover(rig.second, 2)
        #expect(rig.dwells.count == 1)
        #expect(rig.shownTitles == ["Window 2"])
        rig.hover(nil)
        rig.clock += BarPeek.Timing.coolDown * 2
        rig.hover(rig.first)
        #expect(rig.dwells.count == 2, "past the cool-down it dwells")
        #expect(rig.peek.panel.drawn == nil)
    }

    /// A press closes it and the pressed item stays quiet until the
    /// pointer leaves it, as a tooltip does.
    @Test("A press closes the peek until the pointer leaves the item")
    func pressDismisses() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        #expect(rig.shownTitles == ["Window 1"], "was shown")
        rig.peek.dismiss()
        #expect(rig.peek.panel.drawn == nil)
        rig.hover(rig.first)
        rig.step()
        #expect(rig.peek.panel.drawn == nil, "spent until it leaves")
        rig.hover(nil)
        rig.hover(rig.first)
        rig.step()
        #expect(rig.shownTitles == ["Window 1"])
    }

    /// An App Bar item anchoring the peek closes it on a press, as a
    /// glyph does — the item through its own hover report and its
    /// own `mouseDown`.
    @Test("A press on an App Bar item closes its peek")
    func appBarPressDismisses() throws {
        let rig = Rig()
        defer { rig.close() }
        let actions = AppBarItemActions()
        actions.peek = rig.peek
        let item = AppBarItemView(
            frame: CGRect(x: 100, y: 10, width: 40, height: 20)
        )
        item.itemActions = actions
        item.members = [WindowID(3)]
        rig.window.contentView?.addSubview(item)
        try #require(item.peekSource != nil, "the item hides its text")
        item.reportPeek(ownsPointer: true)
        rig.step()
        #expect(rig.shownTitles == ["Window 3"], "was shown")
        #expect(rig.peek.shown?.view === item)
        let press = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
        item.mouseDown(with: press)
        #expect(rig.peek.panel.drawn == nil)
    }

    /// A right-click's or a Control-click's menu closes it too.
    @Test("Any menu opening closes the peek")
    func menuCloses() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        #expect(rig.shownTitles == ["Window 1"], "was shown")
        NotificationCenter.default.post(
            name: NSMenu.didBeginTrackingNotification,
            object: NSMenu()
        )
        #expect(rig.peek.panel.drawn == nil)
    }

    @Test("A relayout that moves the peeked item closes it")
    func movedItemCloses() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        rig.peek.syncToAnchor()
        #expect(rig.peek.panel.drawn != nil, "an unmoved item keeps it")
        rig.first.frame.origin.x += 30
        rig.peek.syncToAnchor()
        #expect(rig.peek.panel.drawn == nil)
        rig.hover(rig.first)
        rig.step()
        #expect(rig.peek.panel.drawn == nil, "spent until it leaves")
    }

    @Test("A removed item closes its peek")
    func removedItemCloses() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        #expect(rig.shownTitles == ["Window 1"], "was shown")
        rig.first.removeFromSuperview()
        rig.peek.syncToAnchor()
        #expect(rig.peek.panel.drawn == nil)
    }

    /// An item view reused for other windows is a new anchor.
    @Test("The same view standing for other windows re-reads")
    func reusedViewReReads() {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first, 1)
        rig.step()
        rig.hover(rig.first, 7)
        #expect(rig.shownTitles == ["Window 7"])
    }

    @Test("The peek panel is read-only, above the bars and unspoken")
    func panelIsReadOnly() throws {
        let rig = Rig()
        defer { rig.close() }
        rig.hover(rig.first)
        rig.step()
        let panel = try #require(rig.peek.panel.panel)
        #expect(panel.ignoresMouseEvents)
        #expect(panel.level == BarPanel.aboveLevel)
        #expect(!panel.isAccessibilityElement())
        #expect(!panel.canBecomeKey)
        #expect(
            rig.peek.panel.body.labels.allSatisfy {
                !$0.isAccessibilityElement()
            }
        )
    }
}
