import AppKit
import KiwiDeskCore
import SwiftUI

/// Owns the dashboard window and its view model. Kept alive by
/// `AppDelegate` so the window survives being closed and
/// reopened from the menu bar.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let model: SettingsModel
    private var window: NSWindow?

    init(core: KiwiCore) {
        self.model = SettingsModel(core: core)
        super.init()
    }

    /// Routes the paused-permission banner's "Enable
    /// Accessibility…" button; the app wires it to the shared
    /// onboarding grant flow.
    func setResolvePermission(_ handler: @escaping () -> Void) {
        model.onResolvePermission = handler
    }

    /// Drives the dashboard-wide paused banner: true while
    /// Accessibility is missing and window management is inert.
    func setPermissionPaused(_ paused: Bool) {
        model.permissionPaused = paused
    }

    /// Non-destructive refresh for the quick menu's layout
    /// actions: recomputes only the live-vs-saved drift
    /// captions, never reseeding `config` — staged edits
    /// survive a session layout switch.
    func refreshLayoutDrift() {
        model.refreshLayoutDrift()
    }

    /// Re-reads the saved-profiles list without discarding staged
    /// edits — so an open dashboard reflects a profile deleted
    /// from the Config Issues panel (#246).
    func refreshProfiles() {
        model.refreshProfiles()
    }

    /// Shows the dashboard already navigated to `destination` —
    /// the read-only shortcuts panel's "Edit in Settings…" bridge
    /// (#326). The request is one-shot; `SettingsView` clears it.
    func show(navigatingTo destination: SettingsDestination) {
        model.pendingDestination = destination
        show()
    }

    /// Shows the dashboard, refreshing from the backend so the
    /// active profile and any external config edits are current —
    /// except when the model holds unsaved edits.
    func show() {
        // Reopening must not discard an unsaved edit (#455). The
        // model is retained across close with its staged `config`
        // and its live-registered hotkeys intact; reseeding it from
        // `gui.json` here would drop the edit, clear the "Unsaved
        // changes" state, and roll the live hotkey back — the
        // "reopen loses my new shortcut" bug. Only a clean model
        // reloads, to pick up external edits (a profile switch, an
        // outside `gui.json` write). Mirrors the non-destructive
        // `refreshProfiles` / `refreshLayoutDrift` above.
        if !model.isDirty {
            model.reload()
        }
        // Promote on every open, not just the first — closing
        // the window demotes to `.accessory`, so a reused
        // window must re-raise to get its Dock icon back.
        NSApp.activateAsRegular()
        if let window {
            NSApp.forceFront(window)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                // Tracks the shell's 840pt minimum (#297) with
                // a little slack on first launch.
                width: 860,
                height: 620
            ),
            styleMask: [
                .titled, .closable, .miniaturizable,
                .resizable, .fullSizeContentView,
            ],
            backing: .buffered,
            defer: false
        )
        window.title = L("sidebar.app_name", "KiwiDesk")
        // Titlebar text hidden: the sidebar header carries the
        // app identity and the detail's own header bar shows the
        // section name. `title` still names the Window menu.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // An empty unified toolbar makes the sidebar run
        // full-height with the traffic lights over it (the
        // System Settings look). The detail's header bar pulls
        // up under it (`ignoresSafeArea` in `SettingsView`), so
        // no empty toolbar strip shows above the header.
        let toolbar = NSToolbar()
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.contentView = NSHostingView(
            rootView: SettingsView(model: model)
                .environmentObject(LocalizationManager.shared)
        )
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("KiwiDeskSettings")
        // A frame saved by a pre-#297 build can be narrower
        // than the shell's new 840pt minimum; min-size only
        // gates user resizing, not the restore, so clamp once.
        if window.frame.width < 840 {
            let content = window.contentRect(
                forFrameRect: window.frame
            )
            window.setContentSize(
                NSSize(width: 860, height: content.height)
            )
        }
        self.window = window

        NSApp.forceFront(window)
    }

    /// Closing the dashboard returns KiwiDesk to menu-bar-only,
    /// so the Dock tile raised in `show()` disappears again —
    /// without this the process keeps a `.regular` Dock icon
    /// after the window is gone. The window itself survives
    /// (`isReleasedWhenClosed = false`) for the next `show()`.
    func windowWillClose(_ notification: Notification) {
        // Guaranteed disarm net (#213): the recorder normally
        // resumes hotkeys via the field's own teardown, but the
        // window is retained (`isReleasedWhenClosed = false`) and
        // merely ordered out, so a close route that never delivers
        // a local mouse-down / app-deactivation could leave the
        // hotkeys suspended. Idempotent — a no-op when nothing is
        // armed.
        model.setRecorderArmed(false)
        // Same class of state, same reasoning (#515): a parked
        // discard closure captured a view that is now gone, and
        // the retained window would carry it into the next
        // `show()` — a dialog about edits that no longer exist.
        model.cancelPendingDiscard()
        // Put the shared color panel away so it can't write
        // into the config after the window is gone.
        ColorPanelController.shared.dismiss()
        // Demote only if no other content window remains (Config
        // Issues / onboarding may still be up).
        NSApp.deactivateIfNoWindows(excluding: window)
    }
}
