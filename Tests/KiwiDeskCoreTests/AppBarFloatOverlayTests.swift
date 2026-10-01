import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The App Bar overlay's float section (#1826): a rule ends the
/// row and the floating mark opens the floats; a float never
/// reorders, the scroll follows a focused float, and VoiceOver
/// says it floats.
@Suite("App Bar float overlay", .serialized)
@MainActor
struct AppBarFloatOverlayTests {
    private func item(_ id: UInt32, floating: Bool = false)
        -> AppBarOverlay.Item
    {
        AppBarOverlay.Item(
            id: WindowID(id),
            name: "App\(id)",
            text: "App\(id)",
            icon: nil,
            floating: floating
        )
    }

    private func show(
        _ overlay: AppBarOverlay,
        _ items: [AppBarOverlay.Item]
    ) {
        overlay.show(
            items: items,
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 800, height: 30),
            style: AppBarLook()
        )
    }

    /// A row of floats alone keeps the mark, leading the run, and
    /// draws no rule (owner, #1838); the run's length and its drawn
    /// span carry the mark too.
    @Test("Floats alone keep the mark ahead of the row and no rule")
    func floatsAloneKeepTheMark() throws {
        let overlay = AppBarOverlay()
        show(overlay, [item(1, floating: true), item(2, floating: true)])
        #expect(overlay.floatRule.isHidden)
        let mark = overlay.floatMark
        #expect(!mark.isHidden)
        let first = overlay.itemViews[0].frame
        #expect(mark.frame.maxX < first.minX)
        #expect(mark.frame.minX >= 0)
        // The drawn span starts at the mark, not the first float.
        #expect(overlay.runContent.minX <= mark.frame.minX + 0.5)
        let m = try #require(overlay.lastMetrics)
        #expect(m.markLead > 0)
        #expect(m.lengths[0] == m.slot + m.markLead)
        #expect(m.lengths[1] == m.slot)
        // A tiled row leading takes no lead.
        show(overlay, [item(3), item(4, floating: true)])
        #expect(try #require(overlay.lastMetrics).markLead == 0)
        #expect(!overlay.floatRule.isHidden)
    }

    @Test("A rule ends the row and the mark opens the floats")
    func markBetweenSections() throws {
        let overlay = AppBarOverlay()
        show(overlay, [item(1), item(2), item(3, floating: true)])
        let mark = overlay.floatMark
        #expect(!mark.isHidden)
        #expect(mark.superview === overlay.itemRun)
        #expect(!mark.isAccessibilityElement())
        #expect(
            mark.hitTest(CGPoint(x: mark.frame.midX, y: mark.frame.midY))
                == nil
        )
        let rule = overlay.floatRule
        #expect(!rule.isHidden)
        #expect(
            rule.hitTest(CGPoint(x: rule.frame.midX, y: rule.frame.midY))
                == nil
        )
        let tiled = overlay.itemViews[1].frame
        let float = overlay.itemViews[2].frame
        // Row, rule, mark, floats — in that order along the axis.
        #expect(rule.frame.minX > tiled.maxX)
        #expect(mark.frame.minX > rule.frame.maxX)
        #expect(mark.frame.maxX < float.minX)
        // Every item keeps the one slot length; the mark widens
        // the run, not an item.
        #expect(tiled.width == float.width)
    }

    /// A tiled row alone draws neither; floats alone keep the mark
    /// and drop the rule (#1838).
    @Test("No break without both sections; floats alone keep the mark")
    func noMarkWithOneSection() {
        let overlay = AppBarOverlay()
        // Drawn first, so each hide below is the render's own.
        show(overlay, [item(1), item(3, floating: true)])
        #expect(!overlay.floatMark.isHidden)
        show(overlay, [item(1), item(2)])
        #expect(overlay.floatMark.isHidden)
        #expect(overlay.floatRule.isHidden)
        show(overlay, [item(1), item(3, floating: true)])
        show(overlay, [item(3, floating: true)])
        #expect(!overlay.floatMark.isHidden)
        #expect(overlay.floatRule.isHidden)
    }

    @Test("A float item neither reorders nor takes a drop")
    func floatDoesNotReorder() {
        let overlay = AppBarOverlay()
        var moves: [(Int, Int)] = []
        overlay.onMove = { moves.append(($0, $1)) }
        show(
            overlay,
            [item(1), item(2), item(3, floating: true)]
        )
        let float = overlay.itemViews[2]
        overlay.dragEnded(float)
        #expect(moves.isEmpty)
        // A tiled item dragged past the break lands last in the
        // row, never among the floats.
        let first = overlay.itemViews[0]
        first.frame.origin.x = overlay.itemViews[2].frame.midX
        overlay.dragEnded(first)
        #expect(moves.map(\.0) == [0])
        #expect(moves.map(\.1) == [1])
    }

    @Test("The bar scrolls to a focused float past its end")
    func scrollFollowsFloat() {
        let overlay = AppBarOverlay()
        let items =
            (1...12).map { item(UInt32($0)) }
            + [item(13, floating: true)]
        overlay.show(
            items: items,
            activeIndex: 12,
            strip: CGRect(x: 0, y: 0, width: 300, height: 30),
            style: AppBarLook()
        )
        let float = overlay.itemViews[12].frame
        let shown = overlay.itemContainer.bounds
            .offsetBy(dx: overlay.scrollOffset, dy: 0)
        #expect(overlay.scrollOffset > 0)
        #expect(shown.contains(float))
    }

    /// A press on a float stays a click: the item view never
    /// starts a drag it has no row to drop into.
    @Test("Pressing and moving on a float still focuses it")
    func floatPressStaysAClick() throws {
        let overlay = AppBarOverlay()
        var selected: [WindowID] = []
        overlay.onSelect = { selected.append($0) }
        show(overlay, [item(1), item(3, floating: true)])
        let view = overlay.itemViews[1]
        for (type, x) in [
            (NSEvent.EventType.leftMouseDown, 10.0),
            (.leftMouseDragged, 40.0),
            (.leftMouseUp, 40.0),
        ] {
            let event = try #require(
                NSEvent.mouseEvent(
                    with: type,
                    location: NSPoint(x: x, y: 10),
                    modifierFlags: [],
                    timestamp: 0,
                    windowNumber: 0,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 1,
                    pressure: 1
                )
            )
            switch type {
            case .leftMouseDown: view.mouseDown(with: event)
            case .leftMouseDragged: view.mouseDragged(with: event)
            default: view.mouseUp(with: event)
            }
        }
        #expect(selected == [WindowID(3)])
    }

    /// English resolves `L()` to its inline text, so a swapped
    /// key shows only in a catalog: German drops the title if the
    /// titled sentence took the app-only key.
    @Test("Each float sentence takes its own key")
    func floatNarrationKeys() {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select("en") }
        let overlay = AppBarOverlay()
        let titled = AppBarOverlay.Item(
            id: WindowID(4),
            name: "Notes",
            text: "Groceries",
            icon: nil,
            floating: true
        )
        show(overlay, [item(1), item(3, floating: true), titled])
        let labels = overlay.itemViews.map { $0.accessibilityLabel() }
        #expect(labels[1] == "App3, schwebendes Fenster")
        #expect(labels[2] == "Notes, schwebendes Fenster Groceries")
    }

    @Test("VoiceOver says the item floats")
    func floatNarration() {
        LocalizationManager.shared.select("en")
        let overlay = AppBarOverlay()
        var titled = item(4, floating: true)
        titled = AppBarOverlay.Item(
            id: titled.id,
            name: "Notes",
            text: "Groceries",
            icon: nil,
            floating: true
        )
        show(overlay, [item(1), item(3, floating: true), titled])
        let labels = overlay.itemViews.map { $0.accessibilityLabel() }
        #expect(
            labels == [
                "App1",
                "App3, floating window",
                "Notes, floating window Groceries",
            ]
        )
    }
}
