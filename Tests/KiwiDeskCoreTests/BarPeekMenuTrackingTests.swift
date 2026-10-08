import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The peek under an open menu (#1946, device eyeball): a menu
/// opening over a peeked item — a right-click's, "N more"'s — and
/// the relayout's hover re-read under the resting pointer showed
/// the peek again beneath the menu. No peek shows while a menu
/// tracks, and the item stays quiet until the pointer leaves it.
@Suite("Bar peek under a menu", .serialized)
@MainActor
struct BarPeekMenuTrackingTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    /// The item's hover reading on `+n` — the relayout's re-read
    /// too.
    private func read(_ rig: BarPeekRig, _ anchor: NSView?) {
        rig.peek.pointer(
            in: rig.item,
            on: anchor,
            source: anchor.map { _ in
                .overflow([WindowID(5), WindowID(6)])
            },
            edge: .top
        )
    }

    /// A menu's tracking, posted where only this rig's peek hears.
    private func menu(_ rig: BarPeekRig, _ name: Notification.Name) {
        rig.menus.post(name: name, object: NSMenu())
    }

    private func shown(_ rig: BarPeekRig) -> Bool {
        rig.peek.panel.drawn != nil
    }

    /// A press closes the peek and a menu opens over the item,
    /// whose tracking closes it again — and a re-read of the resting
    /// pointer must not bring it back.
    @Test("A menu's re-read under the clicked +n shows no peek")
    func noPeekUnderTheMenu() {
        let rig = BarPeekRig()
        defer {
            menu(rig, NSMenu.didEndTrackingNotification)
            rig.close()
        }
        read(rig, rig.first)
        rig.step()
        #expect(shown(rig), "was shown")
        rig.peek.dismiss()
        menu(rig, NSMenu.didBeginTrackingNotification)
        read(rig, rig.first)
        rig.step()
        #expect(!shown(rig), "shown beneath the open menu")
        menu(rig, NSMenu.didEndTrackingNotification)
        read(rig, rig.first)
        rig.step()
        #expect(!shown(rig), "spent until the pointer leaves")
        read(rig, nil)
        read(rig, rig.first)
        rig.step()
        #expect(shown(rig), "peeks again once it left")
    }

    /// A right-click's menu over an item never peeked: no dwell
    /// started under it opens a peek, during or after it.
    @Test("No peek opens while any menu tracks")
    func noPeekWhileTracking() {
        let rig = BarPeekRig()
        defer {
            menu(rig, NSMenu.didEndTrackingNotification)
            rig.close()
        }
        read(rig, rig.first)
        menu(rig, NSMenu.didBeginTrackingNotification)
        rig.step()
        #expect(!shown(rig), "a dwell started before the menu")
        // The pointer leaves the item and comes back under the menu.
        read(rig, nil)
        read(rig, rig.first)
        rig.step()
        #expect(!shown(rig), "a reading during the menu")
        menu(rig, NSMenu.didEndTrackingNotification)
        read(rig, nil)
        read(rig, rig.first)
        rig.step()
        #expect(shown(rig), "peeks once the menu closed")
    }
}
