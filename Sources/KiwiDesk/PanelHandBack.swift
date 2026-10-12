import AppKit
import KiwiDeskCore

/// The show and close of a KiwiDesk key panel, shared by the
/// shortcuts panel and Jump to window. Both are non-activating
/// (#1875): they take the keyboard without activating KiwiDesk,
/// so macOS raises no other own window and the app the user came
/// from stays active — which retired #952's activation hand-back,
/// there being nothing to hand back. What a close still owes is
/// the dismiss distrust, for the one close whose order-out
/// blip-keys another own window: Settings in front.
@MainActor
final class PanelHandBack {
    let core: KiwiCore
    /// Seam answering whether KiwiDesk is the active app (#565).
    var isAppActive: () -> Bool = {
        NSApplication.shared.isActive
    }
    /// Seam for the key order-front (#565).
    var orderFrontKey: (NSWindow) -> Void = {
        $0.makeKeyAndOrderFront(nil)
    }
    /// Seam deferring the order-front to the next main turn.
    var nextTurn: (@escaping @MainActor () -> Void) -> Void = { work in
        DispatchQueue.main.async { MainActor.assumeIsolated(work) }
    }

    init(core: KiwiCore) {
        self.core = core
    }

    /// The app in front as a panel opens, for the panels' logs.
    static func frontmostBundleID() -> String {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            ?? "none"
    }

    /// Keys `panel` without activating KiwiDesk, a turn later, and
    /// only while `stillWanted` — a close in between wins. An
    /// activation raised Settings and re-reported it focused on
    /// every open; keyed in the opening turn, a menu click's close
    /// handed the key back to the window it came from (owner
    /// eyeball, 2026-10-12).
    func present(
        _ panel: NSWindow,
        while stillWanted: @escaping @MainActor () -> Bool = { true }
    ) {
        nextTurn { [weak panel, orderFrontKey] in
            if let panel, stillWanted() { orderFrontKey(panel) }
        }
    }

    /// Closes through `orderOut`, the dismiss distrust armed
    /// BEFORE it: `orderOut`'s resign-key re-enters the close, and
    /// the blip it keys reaches Core ahead of anything after it.
    /// Armed only while the app is active, the one close whose
    /// order-out blip-keys an own window (#952).
    func release(distrusting: Bool, orderOut: () -> Void) {
        if distrusting, isAppActive() {
            core.distrustOwnDismissHandoff()
        }
        orderOut()
    }

    /// The screen a panel opens on: the one under the pointer.
    static func screenUnderPointer() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(mouse, $0.frame, false)
        } ?? NSScreen.main
    }

    /// Centres `window` in `screen`'s visible frame.
    static func center(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen else {
            window.center()
            return
        }
        let frame = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(
            NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
        )
    }
}
