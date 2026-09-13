import AppKit

/// Whether Liquid Glass may be DRAWN right now, as opposed to
/// stored (#1374): the platform has it and the user has not asked
/// macOS to reduce transparency. `NSGlassEffectView` ignores that
/// setting — measured 2026-09-13 on macOS 26.6.2, live and at
/// creation alike — so the bars stand their glass down here, at
/// the one render-time read, while the stored `liquid_glass`
/// value stays the user's.
@MainActor
enum LiquidGlassGate {
    /// The OS read, injectable so a test can flip it.
    static var reducesTransparency: () -> Bool = {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

    /// Platform glass, and transparency not reduced.
    static var drawsGlass: Bool {
        AppBarStyle.glassAvailable && !reducesTransparency()
    }

    /// The style a bar renders: the stored one, glass stood down
    /// and the Fill made opaque while transparency is reduced —
    /// the setting asks for opaque backgrounds, and a 70 % plate
    /// is not one. Every consumer downstream (`glassEnabled`,
    /// `hasBox`, `GlassHosting`, the plate painters) reads the
    /// copy.
    static func rendered(_ style: AppBarStyle) -> AppBarStyle {
        guard reducesTransparency() else { return style }
        var copy = style
        copy.liquidGlass = false
        copy.fillColor = opaque(style.fillColor)
        return copy
    }

    static func rendered(_ style: SpaceBarStyle) -> SpaceBarStyle {
        guard reducesTransparency() else { return style }
        var copy = style
        copy.liquidGlass = false
        copy.fillColor = opaque(style.fillColor)
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

    private static var observer: NSObjectProtocol?

    /// Re-renders through `onChange` whenever the accessibility
    /// display options move. One observer per process; a second
    /// call replaces the first.
    static func observe(_ onChange: @escaping @MainActor () -> Void) {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(
                observer
            )
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace
                .accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onChange() }
        }
    }
}
