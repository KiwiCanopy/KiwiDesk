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

/// The panel the alert's content is hosted in. An `NSAlert` window
/// is not `.closable`, so ⌘W would beep at it once it is key; this
/// one answers Close and Esc by closing for this launch (#1533's
/// shape).
final class OtherWindowManagerPanel: NSPanel {
    var onDismiss: () -> Void = {}

    override func cancelOperation(_ sender: Any?) {
        onDismiss()
    }

    override func performClose(_ sender: Any?) {
        onDismiss()
    }

    override func validateUserInterfaceItem(
        _ item: any NSValidatedUserInterfaceItem
    ) -> Bool {
        if item.action == #selector(NSWindow.performClose(_:)) {
            return true
        }
        return super.validateUserInterfaceItem(item)
    }
}

/// The one-time warning that another window manager runs beside
/// KiwiDesk (#1882). Non-modal: a modal run loop would hold the
/// AX notifications, and the ruling is that tiling never stops. It
/// comes forward like any alert, by the owner's ruling of an alert
/// window, and closes when Core reports that manager gone.
@MainActor
final class OtherWindowManagerAlert: NSObject {
    /// Keeps each shown alert alive until it is answered.
    private static var open: [OtherWindowManagerAlert] = []

    private let alert = NSAlert()
    private let manager: OtherWindowManager
    private let defaults: UserDefaults
    private let quit: () -> Void
    private var panel: OtherWindowManagerPanel?

    /// Whether a detection is shown: never for a manager the user
    /// silenced. Core announces a running manager once.
    static func shouldPresent(
        _ manager: OtherWindowManager,
        defaults: UserDefaults
    ) -> Bool {
        !OtherWindowManagerSilence.isSilenced(manager, in: defaults)
    }

    /// Shows the alert unless `shouldPresent` refuses it; `quit`
    /// asks Core to quit the manager.
    static func present(
        for manager: OtherWindowManager,
        defaults: UserDefaults = .standard,
        quit: @escaping () -> Void
    ) {
        guard shouldPresent(manager, defaults: defaults) else { return }
        let shown = OtherWindowManagerAlert(
            manager: manager,
            defaults: defaults,
            quit: quit
        )
        open.append(shown)
        shown.show()
    }

    /// Closes the alert for a manager Core reports gone.
    static func close(for manager: OtherWindowManager) {
        for shown in open where shown.manager == manager {
            shown.dismiss()
        }
    }

    private init(
        manager: OtherWindowManager,
        defaults: UserDefaults,
        quit: @escaping () -> Void
    ) {
        self.manager = manager
        self.defaults = defaults
        self.quit = quit
    }

    private func show() {
        alert.alertStyle = .warning
        alert.messageText = L(
            "other_wm.alert.title",
            "%1$@ Is Also Managing Windows",
            manager.name
        )
        alert.informativeText = L(
            "other_wm.alert.body",
            "When two window managers arrange the same windows, the "
                + "windows jump between both layouts. Quit the one you "
                + "don't want to use."
        )
        let quit = alert.addButton(
            withTitle: L("other_wm.alert.quit", "Quit %1$@", manager.name)
        )
        quit.target = self
        quit.action = #selector(quitManager)
        let quitKiwiDesk = alert.addButton(
            withTitle: L("menu.quit", "Quit KiwiDesk")
        )
        quitKiwiDesk.target = self
        quitKiwiDesk.action = #selector(quitKiwiDeskInstead)
        let silence = alert.addButton(
            withTitle: L(
                "other_wm.alert.silence",
                "I Know What I'm Doing"
            )
        )
        silence.target = self
        silence.action = #selector(silenceAndDismiss)
        alert.layout()
        let panel = Self.host(alert.window)
        panel.onDismiss = { [weak self] in self?.dismiss() }
        self.panel = panel
        NSApp.forceFront(panel)
    }

    /// Moves the laid-out alert content into a panel that answers
    /// Close; the alert's own window is never shown.
    static func host(_ source: NSWindow) -> OtherWindowManagerPanel {
        let panel = OtherWindowManagerPanel(
            contentRect: source.frame,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        // An accessory app's panel otherwise hides on the first
        // click elsewhere, unanswered.
        panel.hidesOnDeactivate = false
        for button in [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton,
        ] {
            panel.standardWindowButton(button)?.isHidden = true
        }
        panel.contentView = source.contentView
        panel.center()
        return panel
    }

    /// The alert stays until Core reports the manager gone, so a
    /// refusal to quit leaves it up.
    @objc private func quitManager() {
        quit()
    }

    /// Keeps the other manager and leaves through the app's own
    /// quit path.
    @objc private func quitKiwiDeskInstead() {
        dismiss()
        NSApp.terminate(nil)
    }

    @objc private func dismiss() {
        panel?.orderOut(nil)
        Self.open.removeAll { $0 === self }
    }

    @objc private func silenceAndDismiss() {
        OtherWindowManagerSilence.silence(manager, in: defaults)
        dismiss()
    }
}
