import AppKit
import KiwiDeskCore

/// The activation hand-back of a KiwiDesk key panel (#952), shared
/// by the shortcuts panel and Jump to window: the panel takes
/// activation on show, so the app the user came from is
/// remembered and given back only on a keyboard-commanded close —
/// a click-away already activated the clicked app, and handing
/// back would fight it.
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
    /// show, before the panel activates.
    func capture() -> NSRunningApplication? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        returnTarget =
            frontmost?.processIdentifier
                == ProcessInfo.processInfo.processIdentifier
            ? nil : frontmost
        return frontmost
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
