import AppKit
import KiwiDeskCore

/// The show and close of a KiwiDesk key panel, shared by the
/// shortcuts panel and Jump to window. Both panels are
/// non-activating (#1875): they take the keyboard without
/// activating KiwiDesk, so macOS raises no other own window and
/// the app the user came from stays active. Only where KiwiDesk
/// itself was active — Settings in front — does a close still
/// owe the #952 hand-back: the app the user came from is
/// remembered and given back only on a keyboard-commanded close,
/// a click-away having already activated the clicked app.
@MainActor
final class PanelHandBack {
    let core: KiwiCore
    /// The app in front before the panel took activation.
    var returnTarget: NSRunningApplication?
    /// Seam for activating the return target (#565).
    var activateReturnTarget: (NSRunningApplication) -> Void = {
        $0.activate()
    }
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

    /// Whether a close yields activation back: only a commanded
    /// one, of the still-active app, with an app to go back to.
    /// Pure, so all four arms are testable without NSApp.
    static func shouldYield(
        commanded: Bool,
        appActive: Bool,
        target: NSRunningApplication?
    ) -> Bool {
        commanded && appActive && target != nil
    }

    /// Remembers the frontmost app — never KiwiDesk itself — at
    /// show, before the panel takes the key.
    func capture() -> NSRunningApplication? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        returnTarget =
            frontmost?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier
            ? nil : frontmost
        return frontmost
    }

    /// Keys `panel` without activating KiwiDesk. An activation
    /// raised Settings and re-reported it focused on every open
    /// (owner eyeball, 2026-10-12).
    ///
    /// A turn later: a menu click opens the panel while the menu
    /// still tracks, and keyed in that turn the menu's close handed
    /// the key back to the window it came from (owner eyeball,
    /// 2026-10-12: the third open of open, close, open took no
    /// typing).
    func present(_ panel: NSWindow) {
        nextTurn { [weak panel, orderFrontKey] in
            if let panel { orderFrontKey(panel) }
        }
    }

    /// Closes through `orderOut`, in the order #952 needs: the
    /// target is consumed and the dismiss distrust armed BEFORE
    /// `orderOut`, whose resign-key re-enters the close — the
    /// Escape yield went dead in production that way while tests,
    /// with no real key panel, stayed green. The distrust is armed
    /// only while the app is still active, the one close whose
    /// orderOut blips an own window key. Returns the target it
    /// consumed, for a caller whose own act may still need it.
    @discardableResult
    func release(
        yielding: Bool,
        distrusting: Bool,
        orderOut: () -> Void
    ) -> NSRunningApplication? {
        let target = returnTarget
        returnTarget = nil
        let active = isAppActive()
        if distrusting, active {
            core.distrustOwnDismissHandoff()
        }
        orderOut()
        if Self.shouldYield(
            commanded: yielding,
            appActive: active,
            target: target
        ), let target {
            activateReturnTarget(target)
        }
        return target
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
