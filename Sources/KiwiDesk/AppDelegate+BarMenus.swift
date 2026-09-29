import AppKit
import KiwiDeskCore

/// The bars' right-click menus' GUI half (#1518): where a Settings
/// row lands, and the Layout menu's Keep row.
extension AppDelegate {
    func wireBarMenus() {
        core.barMenuHooks.openSettings = { [weak self] landing in
            self?.dashboard.show(landing: landing)
        }
        core.barMenuHooks.keepLayout = { [weak self] in
            self?.keepLayoutInProfile()
        }
    }

    /// The Layout menu's Keep row, from the status item or a Space
    /// chip: capture-live (#1179), the draft's baseline following
    /// through `profiles.onCapturedLive`, which `save_profile`
    /// reaches too.
    func keepLayoutInProfile() {
        guard let name = core.profiles.currentName else { return }
        do {
            try core.persistProfile(named: name, modes: nil)
        } catch {
            core.onLog("profile save failed: \(error)")
            presentLayoutSaveFailure(error)
        }
    }

    /// Alerts on a layout save failure from either Layout menu.
    func presentLayoutSaveFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L(
            "menu.layout.save_failed.title",
            "Couldn't Save Layout"
        )
        alert.informativeText = L(
            "profiles.save_failed",
            "Saving failed: %1$@",
            "\(error)"
        )
        NSApp.activate()
        alert.runModal()
    }
}
