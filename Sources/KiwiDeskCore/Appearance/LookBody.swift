import Foundation

/// A look without a name (#1752): the styling and the colours it
/// wears. What the shared look stores in `gui.json` and what a
/// profile's settings carry of it; a library look is a named one.
public struct LookBody: Codable, Sendable, Equatable {
    /// Styling path (`LookKeys`) to its value.
    public var style: [String: JSONValue]
    /// Colour path (`ColorPaletteKeys`) to hex, every path.
    public var colors: [String: String]

    public init(
        style: [String: JSONValue],
        colors: [String: String]
    ) {
        self.style = style
        self.colors = colors
    }

    /// The look `settings` wear: every styling and colour path.
    public init(of settings: TilingSettings) {
        self.init(
            style: LookKeys.extract(from: settings),
            colors: ColorPaletteKeys.extract(from: settings)
        )
    }

    /// This body under `name`, as the library and a tile read it.
    public func named(_ name: String) -> ShelfLook {
        ShelfLook(name: name, style: style, colors: colors)
    }

    /// `settings` wearing this look — `isWorn`'s pair (#1752).
    /// A per-layout App Bar indicator stays: wearing is no pick,
    /// and only `painted(over:)` clears it (#2368).
    public func worn(over settings: TilingSettings) -> TilingSettings {
        var worn = painted(over: settings)
        worn.monocle.appBar.activeIndicator =
            settings.monocle.appBar.activeIndicator
        worn.scrolling.appBar.activeIndicator =
            settings.scrolling.appBar.activeIndicator
        return worn
    }

    /// `settings` with this look picked: the one copy of the paint,
    /// which clears the per-layout indicators that would hide its
    /// own.
    public func painted(over settings: TilingSettings) -> TilingSettings {
        var painted = settings
        named("").admitted.apply(to: &painted)
        return painted
    }

    /// Whether `settings` already wear this look — `isApplied`'s
    /// answer, never a path diff (#1752), a per-layout indicator
    /// left out as `worn(over:)` leaves it.
    public func isWorn(by settings: TilingSettings) -> Bool {
        var probe = settings
        probe.monocle.appBar.activeIndicator = nil
        probe.scrolling.appBar.activeIndicator = nil
        return named("").admitted.isApplied(to: probe)
    }

    private enum CodingKeys: String, CodingKey {
        case style
        case colors
    }
}
