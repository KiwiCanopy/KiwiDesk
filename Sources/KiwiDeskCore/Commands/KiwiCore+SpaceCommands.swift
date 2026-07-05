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
                // An open quick-terminal-style panel makes AX
                // report the app's main window as focused;
                // following that report would enforce the main
                // window's space under the panel the user is
                // actually typing into (issue #21).
                !FloatDetection.hasVisibleIgnoredPanel(
                    pid: window.pid,
                    appName: window.appName
                ),
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

    /// After a restart, land on the virtual space of the
    /// window the user is focused on right now — the
    /// snapshot's active space is where they were at
    /// shutdown, not where they are. Apps currently showing
    /// an ignored panel are distrusted: while Ghostty's quick
    /// terminal has focus, AX reports the app's *main*
    /// window, which may live on another space (issue #21).
    func activateSpaceOfFocusedWindow() {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            !FloatDetection.hasVisibleIgnoredPanel(
                pid: app.processIdentifier,
                appName: app.localizedName ?? "?"
            ),
            let element = AXHelper.focusedWindow(
                pid: app.processIdentifier
            ),
            let id = AXHelper.windowID(of: element),
            // The cold startup scan may not have tracked the
            // focused window yet — the session snapshot still
            // remembers where it belongs.
            let space = state.workspaces.space(of: id)
                ?? state.rememberedSpace(of: id)
        else { return }
        state.workspaces.activate(space)
    }

    func focusSpace(
        _ args: [JSONValue]
    ) -> CommandResponse {
        guard let raw = args.first?.stringValue else {
            return .fail("expected space id")
        }
        state.workspaces.activate(SpaceID(raw))
        logSpaceContents(SpaceID(raw))
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
        let from = state.workspaces.space(of: focused)
        state.workspaces.add(focused, to: target)
        if from != target {
            emitWindowMovedToSpace(
                focused,
                app: state.windows[focused]?.appName ?? "",
                from: from,
                to: target
            )
        }
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
