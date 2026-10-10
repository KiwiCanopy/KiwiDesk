import AppKit
import KiwiDeskCore

/// The managers the user silenced with "I Know What I'm Doing"
/// (#1882). A preference, not config: it never travels in a backup.
enum OtherWindowManagerSilence {
    static let key = "other_window_managers.silenced"

    static func isSilenced(
        _ manager: OtherWindowManager,
        in defaults: UserDefaults
    ) -> Bool {
        silenced(in: defaults).contains(manager.bundleID)
    }

    static func silence(
        _ manager: OtherWindowManager,
        in defaults: UserDefaults
    ) {
        var ids = silenced(in: defaults)
        guard !ids.contains(manager.bundleID) else { return }
        ids.append(manager.bundleID)
        defaults.set(ids, forKey: key)
    }

    private static func silenced(in defaults: UserDefaults) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }
}

/// The one-time warning that another window manager runs beside
/// KiwiDesk (#1882). Non-modal: a modal run loop would hold the
/// AX notifications, and the ruling is that tiling never stops.
@MainActor
final class OtherWindowManagerAlert: NSObject {
    /// Keeps each shown alert alive until it is answered.
    private static var open: [OtherWindowManagerAlert] = []

    private let alert = NSAlert()
    private let manager: OtherWindowManager
    private let defaults: UserDefaults

    /// Shows the alert unless the user silenced this manager.
    static func present(
        for manager: OtherWindowManager,
        defaults: UserDefaults = .standard
    ) {
        guard
            !OtherWindowManagerSilence.isSilenced(manager, in: defaults)
        else { return }
        let shown = OtherWindowManagerAlert(
            manager: manager,
            defaults: defaults
        )
        open.append(shown)
        shown.show()
    }

    private init(manager: OtherWindowManager, defaults: UserDefaults) {
        self.manager = manager
        self.defaults = defaults
    }

    private func show() {
        alert.alertStyle = .warning
        alert.messageText = L(
            "other_wm.alert.title",
            "%1$@ Is Also Managing Windows",
            manager.name
        )
        alert.informativeText = L(
            "other_wm.alert.message",
            "When two window managers arrange the same windows, the "
                + "windows jump between both layouts. KiwiDesk keeps "
                + "managing your windows. To stop the jumping, quit "
                + "one of them."
        )
        let ok = alert.addButton(withTitle: L("other_wm.alert.ok", "OK"))
        ok.target = self
        ok.action = #selector(dismiss)
        let silence = alert.addButton(
            withTitle: L(
                "other_wm.alert.silence",
                "I Know What I'm Doing"
            )
        )
        silence.target = self
        silence.action = #selector(silenceAndDismiss)
        alert.layout()
        NSApp.forceFront(alert.window)
    }

    @objc private func dismiss() {
        alert.window.orderOut(nil)
        Self.open.removeAll { $0 === self }
    }

    @objc private func silenceAndDismiss() {
        OtherWindowManagerSilence.silence(manager, in: defaults)
        dismiss()
    }
}
