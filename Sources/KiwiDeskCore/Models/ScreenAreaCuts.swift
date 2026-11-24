import CoreGraphics
import Foundation

/// One divider of a split screen (#3517 ruling 20): a full-span
/// cut found in the area rects, never stored. `position` is the
/// cut's x (`.sideBySide`) or y (`.stacked`) in screen points;
/// `start`/`end` its extent along the other axis.
public struct ScreenAreaCut: Equatable, Sendable {
    public enum Axis: String, CaseIterable, Equatable, Sendable {
        /// A vertical line: the areas sit side by side.
        case sideBySide = "side_by_side"
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

/// A split's dividers, read off its runs (`ScreenAreaRuns`), the
/// one guillotine walk validation, Lua, names and Settings share:
/// one cut between each pair of neighbouring members of a run,
/// across that run's box, outer runs first.
public enum ScreenAreaCuts {
    /// The cuts of `areas`, which tile a `width` × `height`
    /// screen; nil when no full-span cut separates them (a
    /// pinwheel), so dividers cannot be derived.
    public static func cuts(
        of areas: [ScreenArea],
        width: Int,
        height: Int
    ) -> [ScreenAreaCut]? {
        guard
            let runs = ScreenAreaRuns.runs(
                of: areas,
                width: width,
                height: height
            )
        else { return nil }
        return runs.flatMap { run in
            zip(run.members, run.members.dropFirst()).map { lead, trail in
                cut(run, at: lead.end, lead: lead, trail: trail, areas)
            }
        }
    }

    private static func cut(
        _ run: ScreenAreaRun,
        at position: Int,
        lead: ScreenAreaRun.Member,
        trail: ScreenAreaRun.Member,
        _ areas: [ScreenArea]
    ) -> ScreenAreaCut {
        func touching(_ member: ScreenAreaRun.Member, _ edge: Bool) -> [Int] {
            ScreenArea.readingOrder(
                areas.filter {
                    member.areas.contains($0.id)
                        && (edge
                            ? ScreenAreaRuns.hi($0, run.axis) == position
                            : ScreenAreaRuns.lo($0, run.axis) == position)
                }
            ).map(\.id)
        }
        return ScreenAreaCut(
            axis: run.axis,
            position: position,
            start: run.crossStart,
            end: run.crossEnd,
            leading: touching(lead, true),
            trailing: touching(trail, false)
        )
    }
}

extension ScreenAreaCut {
    /// Whether `other`, placed at `position` (its own when nil),
    /// lies on this cut: same axis and line, spans overlapping.
    /// Matches a stored divider to a split in flight, and names
    /// the dividers a drag has joined (#3541).
    public func holds(_ other: ScreenAreaCut, at position: Int? = nil) -> Bool
    {
        axis == other.axis && self.position == (position ?? other.position)
            && start < other.end && other.start < end
    }
}
