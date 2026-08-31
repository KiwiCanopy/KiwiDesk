import AppKit
import KiwiDeskCore

/// Menu bar icon rendering methods for `StatusItemController`
/// (`StatusItemSeamGuardTests`).
extension StatusItemController {
    /// Renders standard brand icon on status button
    /// (`BrandAssets.menuBarIcon`).
    func applyBrandIcon(
        to button: NSStatusBarButton,
        a11y: String
    ) {
        button.setAccessibilityLabel(a11y)
        if let icon = BrandAssets.menuBarIcon
            ?? symbol("rectangle.3.group")
        {
            button.image = icon
            button.title = ""
        } else {
            button.image = nil
            button.title = a11y
        }
    }

    /// Sets status button icon to SF Symbol with text fallback.
    func setStatusSymbol(
        _ name: String,
        on button: NSStatusBarButton,
        a11y: String,
        tooltip: String
    ) {
        let image = NSImage(
            systemSymbolName: name,
            accessibilityDescription: a11y
        )
        image?.isTemplate = true
        button.image = image
        button.title = image == nil ? "⚠︎" : ""
        button.toolTip = tooltip
        button.setAccessibilityLabel(a11y)
    }

    /// Renders custom layer or mode icon on status button
    /// (localization audit 2026-08-12).
    func applyModeIcon(
        _ icon: String,
        to button: NSStatusBarButton
    ) {
        button.setAccessibilityLabel(L("menu.status.a11y", "KiwiDesk"))
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
}
