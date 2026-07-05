import AppKit

/// Owns the menu bar item and reflects permission state.
///
/// Shows a persistent warning icon (exclamation triangle) when
/// Accessibility permission is missing or was revoked.
@MainActor
final class StatusItemController {
    var onOpenSettings: () -> Void = {}
    var onOpenDashboard: () -> Void = {}

    private let item: NSStatusItem
    /// Missing-permission warning overrides any mode icon.
    private var warning = false
    /// Active keybinding mode indicator (SF Symbol or emoji);
    /// nil restores the standard KiwiDesk icon.
    private var modeIcon: String?

    init() {
        item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        buildMenu()
        render()
    }

    /// Toggles between the normal and the warning icon.
    func setWarning(_ warning: Bool) {
        self.warning = warning
        render()
    }

    /// Reflects the active keybinding mode: a custom mode's
    /// icon replaces the standard menu bar glyph; the default
    /// mode (nil) restores it (05_GUI_Concept §2, Tab 5).
    func setModeIcon(_ icon: String?) {
        modeIcon = icon
        render()
    }

    private func render() {
        guard let button = item.button else { return }
        if warning {
            button.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription:
                    "KiwiDesk (permission required)"
            )
            button.title = ""
            button.toolTip =
                "KiwiDesk needs Accessibility permission. "
                + "Window management is paused."
            return
        }
        button.toolTip = "KiwiDesk"
        if let modeIcon, !modeIcon.isEmpty {
            applyModeIcon(modeIcon, to: button)
        } else {
            button.title = ""
            button.image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "KiwiDesk"
            )
        }
    }

    /// A mode icon is either an SF Symbol name or a flat emoji;
    /// emoji fall back to the button title when no symbol
    /// matches.
    private func applyModeIcon(
        _ icon: String,
        to button: NSStatusBarButton
    ) {
        if let image = NSImage(
            systemSymbolName: icon,
            accessibilityDescription: icon
        ) {
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = icon
        }
    }

    private func buildMenu() {
        let menu = NSMenu()

        let dashboard = NSMenuItem(
            title: "Settings…",
            action: #selector(openDashboard),
            keyEquivalent: ","
        )
        dashboard.target = self
        menu.addItem(dashboard)

        let settings = NSMenuItem(
            title: "Accessibility Settings…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit KiwiDesk",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        item.menu = menu
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func openDashboard() {
        onOpenDashboard()
    }
}
