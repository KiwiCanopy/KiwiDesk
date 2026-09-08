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
            button.image = icon
            button.title = ""
        } else {
            button.image = nil
            button.title = a11y
        }
    }

    /// The composite's type, so a test can tell the mark from the
    /// bare glyph without reading pixels or riding an announced
    /// property (an `NSImage` NAME is global and refuses a second
    /// holder; a description is what VoiceOver reads off an
    /// unlabelled button).
    final class UpdateMarkImage: NSImage {}

    /// The pending-update mark (#1013, owner ruling 2026-09-08:
    /// orange, top-trailing, Ø5 at the 18 pt master): a dot with a
    /// knockout ring, composited into a NEW image — the shared
    /// brand icon is never mutated (#1311). Not a template, since
    /// a template carries no hue: the handler resolves the bar's
    /// label colour and `systemOrange` at every draw, so light and
    /// dark still follow; the bar's highlight inversion while the
    /// menu is open is what the colour costs (design-decisions.md).
    /// Pure: `render()` alone decides which state carries it.
    static func badged(_ base: NSImage) -> UpdateMarkImage {
        let size = base.size
        let dot = min(size.width, size.height) * 5 / 18
        let ring = dot * 1.5
        let center = CGPoint(
            x: size.width - dot / 2 - 0.5,
            y: size.height - dot / 2 - 0.5
        )
        let image = UpdateMarkImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            NSColor.labelColor.set()
            rect.fill(using: .sourceAtop)
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
            NSColor.systemOrange.setFill()
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
        image.isTemplate = false
        image.accessibilityDescription = base.accessibilityDescription
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
            button.image = image
            button.title = ""
        } else {
            button.image = nil
            button.title = icon
        }
    }
}
