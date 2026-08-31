import AppKit
import KiwiDeskCore

/// Menu bar icon rendering methods for `StatusItemController`
/// (`StatusItemSeamGuardTests`).
extension StatusItemController {
    /// Renders the brand icon, named for VoiceOver by the caller
    /// — starting and ready states draw the SAME glyph, so the
    /// name is what separates them. The label goes on the BUTTON,
    /// not the image: `BrandAssets.menuBarIcon` is a shared cached
    /// `NSImage`, and re-describing it renames it everywhere.
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

    /// Sets status button icon to SF Symbol, or a visible text
    /// fallback: a nil image with an empty title leaves an
    /// invisible-but-clickable slot that reads as a broken app (an
    /// invalid symbol name once did exactly that).
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

    /// Renders custom layer or mode icon. Naming the button is
    /// load-bearing: an accessibility label on an `NSView`
    /// PERSISTS until replaced, so the one path that set none
    /// announced "starting up" on a healthy app indefinitely
    /// (localization audit 2026-08-12) — once one path names the
    /// button, every path owes a name. The name is the app's, not
    /// the icon string's: announcing `star.fill` would be worse
    /// than nothing.
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
