import Foundation

/// A screen number's stored split (#3647 ▸ lane 3): the areas of
/// `ScreenSplit` as per-mille shares of the screen, so one split
/// serves whichever screen holds the number. Its `ScreenArea`s read
/// in per-mille, never points; the split algebra stays on
/// `ScreenSplit`, reached through `resolved(width:height:)` and
/// back through `init(_:width:height:)`.
///
/// Edges are stored, not lengths: neighbours share an edge value,
/// so the resolved areas tile any screen exactly.
public struct ScreenShares: Codable, Equatable, Sendable {
    /// The extent every share is a part of.
    public static let whole = 1000

    public var areas: [ScreenArea]
    public var nextID: Int

    enum CodingKeys: String, CodingKey {
        case areas
        case nextID = "next_id"
    }

    public init(areas: [ScreenArea], nextID: Int? = nil) {
        self.areas = areas
        self.nextID = max(
            nextID ?? 0,
            (areas.map(\.id).max() ?? -1) + 1
        )
    }

    /// `split`, laid on a `width` × `height` screen, as shares. An
    /// edge `previous` already stored at the same point keeps its
    /// share, so a write that resolved and edited a split moves no
    /// edge it did not touch.
    public init(
        _ split: ScreenSplit,
        width: Int,
        height: Int,
        keeping previous: ScreenShares? = nil
    ) {
        let xs = Self.edges(previous, along: \.x, \.w, of: width)
        let ys = Self.edges(previous, along: \.y, \.h, of: height)
        func share(_ p: Int, _ kept: [Int: Int], _ extent: Int) -> Int {
            kept[p] ?? Self.share(p, of: extent)
        }
        self.init(
            areas: split.areas.map { area in
                let x0 = share(area.x, xs, width)
                let x1 = share(area.x + area.w, xs, width)
                let y0 = share(area.y, ys, height)
                let y1 = share(area.y + area.h, ys, height)
                return ScreenArea(
                    id: area.id,
                    x: x0,
                    y: y0,
                    w: x1 - x0,
                    h: y1 - y0,
                    name: area.name
                )
            },
            nextID: split.nextID
        )
    }

    /// `previous`'s edges along one axis, keyed by the point each
    /// resolves to on `extent`.
    private static func edges(
        _ previous: ScreenShares?,
        along origin: KeyPath<ScreenArea, Int>,
        _ length: KeyPath<ScreenArea, Int>,
        of extent: Int
    ) -> [Int: Int] {
        var kept: [Int: Int] = [:]
        for area in previous?.areas ?? [] {
            for e in [
                area[keyPath: origin],
                area[keyPath: origin] + area[keyPath: length],
            ] {
                kept[points(e, of: extent)] = e
            }
        }
        return kept
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let areas = try c.decode([ScreenArea].self, forKey: .areas)
        self.init(
            areas: areas,
            nextID: try c.decodeIfPresent(Int.self, forKey: .nextID)
        )
    }

    /// These shares in points on a `width` × `height` screen.
    public func resolved(width: Int, height: Int) -> ScreenSplit {
        ScreenSplit(
            areas: areas.map { area in
                let x = Self.points(area.x, of: width)
                let y = Self.points(area.y, of: height)
                return ScreenArea(
                    id: area.id,
                    x: x,
                    y: y,
                    w: Self.points(area.x + area.w, of: width) - x,
                    h: Self.points(area.y + area.h, of: height) - y,
                    name: area.name
                )
            },
            nextID: nextID
        )
    }

    /// These shares on the screen `fingerprint` names, at the size
    /// it carries (`Name:WxH`, the frame it was read from); nil for
    /// a fingerprint with no size.
    public func resolved(on fingerprint: String) -> ScreenSplit? {
        Self.size(of: fingerprint).map {
            resolved(width: $0.width, height: $0.height)
        }
    }

    /// The first problem with these shares as a split, judged in
    /// per-mille with no area floor; nil where they tile the screen.
    public var problem: ScreenAreaProblem? {
        ScreenArea.problem(
            with: areas,
            width: Self.whole,
            height: Self.whole,
            minimumSide: 1
        )
    }

    /// The whole screen as one area 0, minting past `previous`'s
    /// ids (ruling 21).
    public static func whole(after previous: ScreenShares?) -> ScreenShares {
        ScreenShares(
            areas: [ScreenArea(id: 0, x: 0, y: 0, w: whole, h: whole)],
            nextID: previous?.nextID
        )
    }

    /// Whether these shares leave the screen whole.
    public var isWhole: Bool { areas.count <= 1 }

    /// The size a fingerprint carries, nil where it has none.
    public static func size(
        of fingerprint: String
    ) -> (width: Int, height: Int)? {
        let sides = Display.fingerprintParts(fingerprint).size
            .split(separator: "x").compactMap { Int($0) }
        guard sides.count == 2, sides[0] > 0, sides[1] > 0 else {
            return nil
        }
        return (sides[0], sides[1])
    }

    /// `p` points of `extent` as an edge in per-mille, rounded.
    static func share(_ p: Int, of extent: Int) -> Int {
        guard extent > 0 else { return 0 }
        return (p * whole * 2 + extent) / (extent * 2)
    }

    /// Edge `e` per-mille of `extent` in points, rounded half up:
    /// 0 is 0 and `whole` is `extent` exactly.
    static func points(_ e: Int, of extent: Int) -> Int {
        (e * extent + whole / 2) / whole
    }
}
