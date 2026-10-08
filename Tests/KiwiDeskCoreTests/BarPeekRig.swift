import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A host window with two anchors in one reporter, and a peek whose
/// dwell, clock and pointer are stepped by hand — the peek suites'
/// shared fixture (#1946).
@MainActor
final class BarPeekRig {
    let menus = NotificationCenter()
    lazy var peek = BarPeek(menus: menus)
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
    /// The pointer on screen; off every screen until a test moves it.
    var pointer = CGPoint(x: -1e6, y: -1e6)
    /// What the peek's pick and "N more" were handed.
    var picks: [(WindowID, SpaceID?)] = []
    var menusOpened: [BarPeekSource] = []

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
        peek.pointerOnScreen = { [unowned self] in pointer }
        // A runner's screen may not hold the host window, which
        // would fit every list into the window's own frame.
        peek.visibleArea = { _ in
            CGRect(x: 0, y: 0, width: 1920, height: 1200)
        }
        peek.shelf = { _ in KiwiShelf() }
        peek.pick = { [unowned self] id, space in picks.append((id, space)) }
        peek.openMenu = { [unowned self] source, _, _ in
            menusOpened.append(source)
        }
    }

    func hover(_ anchor: NSView?, _ ids: UInt32...) {
        let windows = (ids.isEmpty ? [1] : ids).map(WindowID.init)
        peek.pointer(
            in: item,
            on: anchor,
            source: anchor.map { _ in .glyph(windows) },
            space: SpaceID("1"),
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

    /// A point in the gap between `first` and the shown peek: below
    /// the item's bottom edge and above the peek's top, on a top bar.
    func gap() throws -> CGPoint {
        let item = screen(first)
        let peek = try #require(peek.panel.panel?.frame)
        #expect(peek.maxY < item.minY, "a top bar's peek opens below")
        return CGPoint(x: item.midX, y: (peek.maxY + item.minY) / 2)
    }

    /// `view`'s frame on screen.
    func screen(_ view: NSView) -> CGRect {
        window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    func close() {
        peek.dismiss()
        peek.panel.panel?.orderOut(nil)
        window.orderOut(nil)
    }
}
