import CoreGraphics
import Foundation

/// One divider of a split screen (#3517 ruling 20): a full-span
/// cut found in the area rects, never stored. `position` is the
/// cut's x (`.sideBySide`) or y (`.stacked`) in screen points;
/// `start`/`end` its extent along the other axis.
public struct ScreenAreaCut: Equatable, Sendable {
    public enum Axis: Equatable, Sendable {
        /// A vertical line: the areas sit side by side.
        case sideBySide
        /// A horizontal line: the areas are stacked.
        case stacked
    }

    public let axis: Axis
    public let position: Int
    public let start: Int
    public let end: Int
    /// The areas whose trailing edge lies on the cut, then those
    /// whose leading edge does — only the areas touching it.
    public let leading: [Int]
    public let trailing: [Int]
}

/// Derives a split's dividers from its rects: the one derivation
/// validation, Lua, labels and Settings share.
public enum ScreenAreaCuts {
    /// The cuts of `areas`, which tile a `width` × `height`
    /// screen; nil when no full-span cut separates them (a
    /// pinwheel), so dividers cannot be derived.
    public static func cuts(
        of areas: [ScreenArea],
        width: Int,
        height: Int
    ) -> [ScreenAreaCut]? {
        var out: [ScreenAreaCut] = []
        let ok = collect(
            areas,
            in: (x: 0, y: 0, w: width, h: height),
            into: &out
        )
        return ok ? out : nil
    }

    private typealias Box = (x: Int, y: Int, w: Int, h: Int)

    private static func collect(
        _ areas: [ScreenArea],
        in box: Box,
        into out: inout [ScreenAreaCut]
    ) -> Bool {
        guard areas.count > 1 else { return true }
        for axis in [ScreenAreaCut.Axis.sideBySide, .stacked] {
            guard let at = firstCut(areas, box: box, axis: axis)
            else { continue }
            let (lead, trail) = partition(areas, at: at, axis: axis)
            out.append(cut(axis, at, box, lead, trail))
            let (a, b) = halves(box, at: at, axis: axis)
            return collect(lead, in: a, into: &out)
                && collect(trail, in: b, into: &out)
        }
        return false
    }

    private static func lo(_ a: ScreenArea, _ axis: ScreenAreaCut.Axis)
        -> Int
    { axis == .sideBySide ? a.x : a.y }

    private static func hi(_ a: ScreenArea, _ axis: ScreenAreaCut.Axis)
        -> Int
    { axis == .sideBySide ? a.x + a.w : a.y + a.h }

    /// The smallest inner position no area straddles.
    private static func firstCut(
        _ areas: [ScreenArea],
        box: Box,
        axis: ScreenAreaCut.Axis
    ) -> Int? {
        let origin = axis == .sideBySide ? box.x : box.y
        let candidates = Set(areas.map { lo($0, axis) })
            .filter { $0 > origin }
            .sorted()
        return candidates.first { at in
            !areas.contains { lo($0, axis) < at && hi($0, axis) > at }
        }
    }

    private static func partition(
        _ areas: [ScreenArea],
        at: Int,
        axis: ScreenAreaCut.Axis
    ) -> ([ScreenArea], [ScreenArea]) {
        (
            areas.filter { hi($0, axis) <= at },
            areas.filter { lo($0, axis) >= at }
        )
    }

    private static func halves(
        _ box: Box,
        at: Int,
        axis: ScreenAreaCut.Axis
    ) -> (Box, Box) {
        if axis == .sideBySide {
            return (
                (box.x, box.y, at - box.x, box.h),
                (at, box.y, box.x + box.w - at, box.h)
            )
        }
        return (
            (box.x, box.y, box.w, at - box.y),
            (box.x, at, box.w, box.y + box.h - at)
        )
    }

    private static func cut(
        _ axis: ScreenAreaCut.Axis,
        _ at: Int,
        _ box: Box,
        _ lead: [ScreenArea],
        _ trail: [ScreenArea]
    ) -> ScreenAreaCut {
        let span =
            axis == .sideBySide
            ? (box.y, box.y + box.h) : (box.x, box.x + box.w)
        return ScreenAreaCut(
            axis: axis,
            position: at,
            start: span.0,
            end: span.1,
            leading: ScreenArea.readingOrder(
                lead.filter { hi($0, axis) == at }
            ).map(\.id),
            trailing: ScreenArea.readingOrder(
                trail.filter { lo($0, axis) == at }
            ).map(\.id)
        )
    }
}
