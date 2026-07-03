import AppKit

/// Owns the menu bar item and reflects permission state.
///
/// Shows a persistent warning icon (exclamation triangle) when
/// Accessibility permission is missing or was revoked.
@MainActor
final class StatusItemController {
    var onOpenSettings: () -> Void = {}

    private let item: NSStatusItem

    init() {
        item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        buildMenu()
        setWarning(false)
    }

    /// Toggles between the normal and the warning icon.
    func setWarning(_ warning: Bool) {
        guard let button = item.button else { return }
        let symbol =
            warning
            ? "exclamationmark.triangle.fill"
            : "rectangle.3.group"
        let description =
            warning
            ? "KiwiDesk (permission required)"
            : "KiwiDesk"
        button.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: description
        )
        button.toolTip =
            warning
            ? "KiwiDesk needs Accessibility permission. "
                + "Window management is paused."
            : "KiwiDesk"
    }

    private func buildMenu() {
        let menu = NSMenu()

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
}
