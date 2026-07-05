import AppKit
import KiwiDeskCore
import SwiftUI

/// Owns the dashboard window and its view model. Kept alive by
/// `AppDelegate` so the window survives being closed and
/// reopened from the menu bar.
@MainActor
final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?

    init(core: KiwiCore) {
        self.model = SettingsModel(core: core)
    }

    /// Shows the dashboard, refreshing from the backend so the
    /// active profile and any external config edits are current.
    func show() {
        model.reload()
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
        window.title = "KiwiDesk"
        window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(
            rootView: SettingsView(model: model)
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("KiwiDeskSettings")
        self.window = window

        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
