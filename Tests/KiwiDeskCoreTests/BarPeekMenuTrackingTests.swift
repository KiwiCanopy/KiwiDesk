import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The peek under an open menu (#1946, device eyeball): a click on
/// `+n` closed the peek and opened its menu, and the relayout's
/// hover re-read under the resting pointer showed the peek again
/// beneath the menu. No peek shows while a menu tracks, and the
/// clicked item stays quiet until the pointer leaves it.
@Suite("Bar peek under a menu", .serialized)
@MainActor
struct BarPeekMenuTrackingTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    @MainActor
    private final class Rig {
        let menus = NotificationCenter()
        lazy var peek = BarPeek(menus: menus)
        let window = NSPanel(
            contentRect: CGRect(x: 200, y: 800, width: 400, height: 40),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let item = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        let more = NSView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        var steps: [@MainActor () -> Void] = []

        init() {
            window.contentView?.addSubview(item)
            item.addSubview(more)
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
            peek.schedule = { [unowned self] _, body in
                steps.append(body)
            }
            peek.shelf = { _ in KiwiShelf() }
        }

        /// The item's hover reading — the relayout's re-read too.
        func read(_ anchor: NSView?) {
            peek.pointer(
                in: item,
                on: anchor,
                source: anchor.map { _ in
                    .overflow([WindowID(5), WindowID(6)])
                },
                edge: .top
            )
        }

        func step() {
            let pending = steps
            steps = []
            pending.forEach { $0() }
        }

        func menu(_ name: Notification.Name) {
            menus.post(name: name, object: NSMenu())
        }

        var shown: Bool { peek.panel.drawn != nil }

        func close() {
            menu(NSMenu.didEndTrackingNotification)
            peek.dismiss()
            peek.panel.panel?.orderOut(nil)
            window.orderOut(nil)
        }
    }

    /// The click's own sequence: the press dismisses, the release
    /// opens the menu, whose tracking dismisses again — and a
    /// re-read of the resting pointer must not bring it back.
    @Test("A menu's re-read under the clicked +n shows no peek")
    func noPeekUnderTheMenu() {
        let rig = Rig()
        defer { rig.close() }
        rig.read(rig.more)
        rig.step()
        #expect(rig.shown, "was shown")
        rig.peek.dismiss()
        rig.menu(NSMenu.didBeginTrackingNotification)
        rig.read(rig.more)
        rig.step()
        #expect(!rig.shown, "shown beneath the open menu")
        rig.menu(NSMenu.didEndTrackingNotification)
        rig.read(rig.more)
        rig.step()
        #expect(!rig.shown, "spent until the pointer leaves")
        rig.read(nil)
        rig.read(rig.more)
        rig.step()
        #expect(rig.shown, "peeks again once it left")
    }

    /// A right-click's menu over an item never peeked: no dwell
    /// started under it opens a peek, during or after it.
    @Test("No peek opens while any menu tracks")
    func noPeekWhileTracking() {
        let rig = Rig()
        defer { rig.close() }
        rig.read(rig.more)
        rig.menu(NSMenu.didBeginTrackingNotification)
        rig.step()
        #expect(!rig.shown, "a dwell started before the menu")
        // The pointer leaves the item and comes back under the menu.
        rig.read(nil)
        rig.read(rig.more)
        rig.step()
        #expect(!rig.shown, "a reading during the menu")
        rig.menu(NSMenu.didEndTrackingNotification)
        rig.read(nil)
        rig.read(rig.more)
        rig.step()
        #expect(rig.shown, "peeks once the menu closed")
    }
}
