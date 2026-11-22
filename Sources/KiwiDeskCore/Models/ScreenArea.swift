import CoreGraphics
import Foundation

/// One area of a split screen (#3517): a rectangle in whole points
/// of its physical screen, origin top-left, y growing down, so
/// reading order is ascending `y` then `x`. A screen's split is a
/// flat list of these, never a tree; the direction is read from
/// the rectangles, never stored.
public struct ScreenArea: Codable, Hashable, Sendable {
    /// Minted once and kept: the area holding id 0 answers to the
    /// screen's bare fingerprint (`ScreenAreaKey`).
    public var id: Int
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int
    /// The user's own name; nil shows the positional default.
    public var name: String?

    /// Smallest side an area may have, in points: no window can
    /// render below it. Lua refuses less; Settings floors higher,
    /// at the layouts' minimum window size (#3517 ruling 3).
    public static let minimumSide = 100

    public init(
        id: Int,
        x: Int,
        y: Int,
        w: Int,
        h: Int,
        name: String? = nil
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.name = name
    }

    /// The area's rect in its screen's own points.
    public var rect: CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    /// `areas` sorted into reading order: top to bottom, then
    /// left to right.
    public static func readingOrder(
        _ areas: [ScreenArea]
    ) -> [ScreenArea] {
        areas.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    }
}
