import AppKit
import Foundation

/// Virtual space commands: `focus_virtual_space` and
/// `move_to_virtual_space(_and_follow)`.
extension KiwiCore {
    /// Follows focus into a hidden window's virtual space —
    /// but only if that window is still the frontmost app's
    /// AX-focused window after a settle delay. Immediate
    /// following would act on the transient focus re-report
    /// that app activation emits just before a NEW window
    /// opens, dragging the user (and the new window) to the
    /// old window's space.
    func scheduleFocusFollow(_ id: WindowID) {
        // Focus reports during a native desktop transition
        // reference windows that are being re-tracked; they
        // must not flip the virtual space mid-restore.
        guard
            Date().timeIntervalSince(lastNativeSwitch) > 1
        else { return }
        pendingFocusFollow?.cancel()
        pendingFocusFollow = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            guard let window = self.state.windows[id],
                NSWorkspace.shared.frontmostApplication?
                    .processIdentifier == window.pid,
                let element = AXHelper.focusedWindow(
                    pid: window.pid
                ),
                AXHelper.windowID(of: element) == id,
                let space = self.state.workspaces.space(
                    of: id
                ),
                space != self.state.workspaces.activeSpace
            else { return }
            self.state.workspaces.activate(space)
            self.retile(
                animated: self.tiler.animateSpaceSwitch,
                force: true
            )
            self.emitSpaceChange()
        }
    }

    func focusSpace(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        state.workspaces.activate(SpaceID(raw))
        retile(
            animated: tiler.animateSpaceSwitch,
            force: true
        )
        // Hand real (AX) focus to the space's last focused
        // window — otherwise keystrokes keep going to a
        // window that is now stashed offscreen.
        if let next = activeSpace?.focused {
            focusWindow(next)
        }
        emitSpaceChange()
        return .ok()
    }

    func moveToSpace(
        _ args: [JSONValue],
        follow: Bool
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        guard let focused = activeSpace?.focused else {
            return .fail("no focused window")
        }
        let target = SpaceID(raw)
        state.workspaces.add(focused, to: target)
        if follow {
            state.workspaces.activate(target)
            focusWindow(focused)
            emitSpaceChange()
        } else if let next = activeSpace?.focused {
            // The moved window would keep macOS focus while
            // stashed offscreen; refocus the current space.
            focusWindow(next)
        }
        retile(
            animated: follow
                ? tiler.animateSpaceSwitch : true,
            force: follow
        )
        return .ok()
    }
}
