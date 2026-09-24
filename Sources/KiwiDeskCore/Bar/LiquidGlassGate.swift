import AppKit

/// Whether Liquid Glass may be DRAWN right now, as opposed to
/// stored: the platform has it and macOS's Reduce transparency is
/// off (#1374, bars.md ▸ Reduce transparency). The one Core
/// reader of that setting; the stored `liquid_glass` never moves.
@MainActor
enum LiquidGlassGate {
    #if DEBUG
        /// Test seam over the OS read; nil reads the machine.
        static var override: (() -> Bool)?
    #endif

    static var reducesTransparency: Bool {
        #if DEBUG
            if let override { return override() }
        #endif
        return NSWorkspace.shared
            .accessibilityDisplayShouldReduceTransparency
    }

    /// Platform glass, and transparency not reduced.
    static var drawsGlass: Bool {
        AppBarStyle.glassAvailable && !reducesTransparency
    }

    /// The style a bar renders: the stored one, glass stood down
    /// and both fills at full alpha while transparency is reduced
    /// — the setting asks for opaque backgrounds.
    static func rendered(_ style: AppBarLook) -> AppBarLook {
        guard reducesTransparency else { return style }
        var copy = style
        copy.liquidGlass = false
        copy.fillColor = opaque(style.fillColor)
        copy.hoverFillColor = opaque(style.hoverFillColor)
        return copy
    }

    static func rendered(_ style: SpaceBarLook) -> SpaceBarLook {
        guard reducesTransparency else { return style }
        var copy = style
        copy.liquidGlass = false
        copy.fillColor = opaque(style.fillColor)
        copy.hoverFillColor = opaque(style.hoverFillColor)
        return copy
    }

    /// The shelf the plate renders from — the same stand-down
    /// as a bar's, since the plate is where the fill is drawn.
    static func rendered(_ shelf: KiwiShelf) -> KiwiShelf {
        guard reducesTransparency else { return shelf }
        var copy = shelf
        copy.liquidGlass = false
        copy.fillColor = opaque(shelf.fillColor)
        copy.hoverFillColor = opaque(shelf.hoverFillColor)
        return copy
    }

    /// A Fill at full alpha, keeping its hue. A fully transparent
    /// Fill stays so: it asked for no plate, and none is opaque.
    static func opaque(_ hex: String) -> String {
        guard let rgba = DragVisual.parseHex(hex), rgba.alpha > 0
        else { return hex }
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : hex[...]
        return "#" + digits.prefix(6)
    }

    /// Fires `onChange` on the main actor whenever the
    /// accessibility display options move; the caller owns the
    /// token.
    static func observe(
        _ onChange: @escaping @MainActor () -> Void
    ) -> NSObjectProtocol {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace
                .accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onChange() }
        }
    }
}
