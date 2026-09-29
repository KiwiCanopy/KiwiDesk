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

    /// `settings` with this look painted over — `isWorn`'s pair,
    /// and the one copy of the paint (#1752).
    public func worn(over settings: TilingSettings) -> TilingSettings {
        var worn = settings
        named("").admitted.apply(to: &worn)
        return worn
    }

    /// Whether `settings` already wear this look — `isApplied`'s
    /// answer, never a path diff (#1752).
    public func isWorn(by settings: TilingSettings) -> Bool {
        named("").admitted.isApplied(to: settings)
    }

    private enum CodingKeys: String, CodingKey {
        case style
        case colors
    }
}
