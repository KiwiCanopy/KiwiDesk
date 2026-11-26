import Foundation

/// A look without a name (#1752): the styling and the colours it
/// wears. What the shared look stores in `gui.json` and what a
/// profile's settings carry of it; a library look is a named one.
public struct LookBody: Codable, Sendable, Equatable {
    /// Styling path (`LookKeys`) to its value.
    public var style: [String: JSONValue]
    /// Colour path (`ColorPaletteKeys`) to hex, every path.
    public var colors: [String: String]
    /// The authored look it was painted from
    /// (`TilingSettings.lookOrigin`), so every follower credits it.
    public var origin: ShelfLook?
    /// The picture wearing it sets (`TilingSettings.lookWallpaper`,
    /// #3478), so every follower sets it too.
    public var wallpaper: LookWallpaper?

    public init(
        style: [String: JSONValue],
        colors: [String: String],
        origin: ShelfLook? = nil,
        wallpaper: LookWallpaper? = nil
    ) {
        self.style = style
        self.colors = colors
        self.origin = origin
        self.wallpaper = wallpaper
    }

    /// The look `settings` wear: every styling and colour path.
    public init(of settings: TilingSettings) {
        self.init(
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: settings),
            origin: settings.lookOrigin,
            wallpaper: settings.lookWallpaper
        )
    }

    /// This body under `name`, as the library and a tile read it.
    public func named(_ name: String) -> ShelfLook {
        ShelfLook(name: name, style: style, colors: colors)
    }

    /// `settings` wearing this look — `isWorn`'s pair (#1752).
    /// Wearing is no pick, so a per-layout App Bar indicator stays,
    /// which a picked look (`ShelfLook.apply`) clears (#2368).
    public func worn(over settings: TilingSettings) -> TilingSettings {
        var worn = settings
        named("").admitted.apply(to: &worn)
        for leaf in TilingSettings.layoutIndicatorLeaves {
            worn[keyPath: leaf] = settings[keyPath: leaf]
        }
        worn.lookOrigin = origin
        worn.lookWallpaper = wallpaper?.admitted
        return worn
    }

    /// Whether `settings` already wear this look — `isApplied`'s
    /// answer, never a path diff (#1752), a per-layout indicator
    /// left out as `worn(over:)` leaves it.
    public func isWorn(by settings: TilingSettings) -> Bool {
        var probe = settings
        for leaf in TilingSettings.layoutIndicatorLeaves {
            probe[keyPath: leaf] = nil
        }
        return named("").admitted.isApplied(to: probe)
    }

    /// Whether `settings` wear this look AND carry its origin — what
    /// a follower's file copy must hold, so a re-stamp also reaches
    /// one that differs only in its credit (#1740). Ownership
    /// verdicts read `isWorn`, the paint alone.
    public func isStamped(on settings: TilingSettings) -> Bool {
        settings.lookOrigin == origin
            && settings.lookWallpaper == wallpaper?.admitted
            && isWorn(by: settings)
    }

    private enum CodingKeys: String, CodingKey {
        case style
        case colors
        case origin
        case wallpaper
    }
}
