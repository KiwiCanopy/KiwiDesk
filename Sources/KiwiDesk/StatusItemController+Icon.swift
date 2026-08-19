import AppKit
import KiwiDeskCore

/// The three glyph painters the icon state machine dispatches to:
/// the brand mark, an SF Symbol, and a user-supplied mode icon.
///
/// Lifted out of `StatusItemController.swift` when that file
/// reached §2.1's 350-line ceiling, matching the `+Menu` /
/// `+Layout` split already beside it.
///
/// A NARROW slice on purpose. The state machine itself
/// (`setWarning`, `setConfigError`, `render` and the stored flags
/// they drive) stayed behind, because moving it would have meant
/// widening private stored state to `internal` just to reach it
/// across a file boundary — paying for a line count with
/// encapsulation. These three take everything they need as
/// parameters, so the move costs nothing. `SystemStatusItem`
/// stayed behind too: `StatusItemSeamGuardTests` pins it to the
/// controller file BY NAME, and that seal is the point of it.
extension StatusItemController {
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
            // Last-ditch: never leave the slot blank.
            button.image = nil
            button.title = a11y
        }
    }

    /// Sets the status button to the SF Symbol `name`, or — if
    /// that symbol doesn't resolve on this macOS version — a
    /// visible text fallback, so the menu bar item is never blank.
    /// A nil image with an empty title leaves an
    /// invisible-but-clickable slot that reads as a broken app
    /// (an invalid symbol name — `doc.badge.exclamationmark`,
    /// which does not exist — once did exactly that).
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
        // Same reason as `applyBrandIcon`: name the button, not
        // the image, so every state announces itself even when
        // the text fallback is what rendered.
        button.setAccessibilityLabel(a11y)
    }

    /// A mode icon is either an SF Symbol name or a flat
    /// emoji; emoji fall back to the button title when no
    /// symbol matches.
    ///
    /// It names the button like every other render path, and that
    /// is load-bearing rather than tidy: an accessibility label on
    /// an `NSView` PERSISTS until something replaces it, so the
    /// one path that set none inherited whatever the last one said
    /// — switch layers after boot and the mark still announced
    /// "KiwiDesk (starting up)", on a healthy app, indefinitely
    /// (localization audit, 2026-08-12). Once one path names the
    /// button, every path owes a name.
    ///
    /// The name is the app's, not the layer's: the icon string is
    /// an SF Symbol identifier or a bare emoji from the user's Lua
    /// config, and announcing `star.fill` would be worse than
    /// announcing nothing. Naming the active LAYER needs the
    /// layer's name at this seam, which is #TBD rather than this
    /// change set.
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

    /// Shared SF Symbol → template-image helper for the menu
    /// builders (`+Menu`, `+Layout`) and `render`.
}
