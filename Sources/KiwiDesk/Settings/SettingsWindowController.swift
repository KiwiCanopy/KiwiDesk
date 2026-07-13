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

    /// Shows the dashboard, refreshing from the backend so the
    /// active profile and any external config edits are current.
    func show() {
        model.reload()
        // Promote on every open, not just the first — closing
        // the window demotes to `.accessory`, so a reused
        // window must re-raise to get its Dock icon back.
        NSApp.activateAsRegular()
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 820,
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
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
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
        // Put the shared color panel away so it can't write
        // into the config after the window is gone.
        ColorPanelController.shared.dismiss()
        // Demote only if no other content window remains (Config
        // Issues / onboarding may still be up).
        NSApp.deactivateIfNoWindows(excluding: window)
    }
}
