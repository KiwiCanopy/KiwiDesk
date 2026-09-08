import AppKit
import KiwiDeskCore

/// Menu bar icon rendering methods for `StatusItemController`
/// (`StatusItemSeamGuardTests`).
extension StatusItemController {
    /// Renders the brand icon, named for VoiceOver by the caller
    /// — starting and ready states draw the SAME glyph, so the
    /// name is what separates them. The STATE name goes on the
    /// BUTTON, not the image: `BrandAssets.menuBarIcon` is one
    /// shared `NSImage`, so a per-state description there would
    /// rename it everywhere. Its own description stays the
    /// product name, which no state varies (#1311).
    func applyBrandIcon(
        to button: NSStatusBarButton,
        a11y: String
    ) {
        button.setAccessibilityLabel(a11y)
        if let icon = BrandAssets.menuBarIcon
            ?? symbol("rectangle.3.group")
        {
            button.image = badged(icon)
            button.title = ""
        } else {
            button.image = nil
            button.title = a11y
        }
    }

    /// The pending-update mark (#1013): a dot with a knockout ring
    /// at the top-trailing corner, composited into a NEW template
    /// image — the shared brand icon is never mutated (#1311), and
    /// a template carries no hue, so the mark separates by shape
    /// alone and needs no colour-vision floor. The fixed black is
    /// a template's alpha, not an ink. Drawn per backing scale by
    /// the handler initializer. Only the healthy glyphs carry it:
    /// a warning or a config error outranks an offer.
    func badged(_ base: NSImage) -> NSImage {
        guard updatePending else { return base }
        let size = base.size
        let dot = min(size.width, size.height) / 3
        let ring = dot * 1.5
        let center = CGPoint(
            x: size.width - dot / 2 - 0.5,
            y: size.height - dot / 2 - 0.5
        )
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            let context = NSGraphicsContext.current
            context?.compositingOperation = .destinationOut
            NSBezierPath(
                ovalIn: CGRect(
                    x: center.x - ring / 2,
                    y: center.y - ring / 2,
                    width: ring,
                    height: ring
                )
            ).fill()
            context?.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(
                ovalIn: CGRect(
                    x: center.x - dot / 2,
                    y: center.y - dot / 2,
                    width: dot,
                    height: dot
                )
            ).fill()
            return true
        }
        image.isTemplate = true
        return image
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
            button.image = badged(image)
            button.title = ""
        } else {
            button.image = nil
            button.title = icon
        }
    }
}
