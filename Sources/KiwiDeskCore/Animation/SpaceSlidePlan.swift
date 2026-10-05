import CoreGraphics
import Foundation

/// The Space-switch plate slide's pure half (#1956): its timeline,
/// the axis and direction a strip travels, and the plates one page
/// shows. `SpaceSlideOverlay` draws what this decides; the ruling
/// behind every number is #1956's body ▸ "Ruling update".
enum SpaceSlidePlan {
    /// The plates fade in over the windows shown now.
    static let fadeIn: TimeInterval = 0.08
    /// The strip waits this long after a press: the outgoing parks
    /// leave AT the press, and apps take 60–100 ms to perform one.
    static let stripDelay: TimeInterval = 0.12
    /// The strip's critically damped spring response.
    static let response: TimeInterval = 0.30
    /// When the spring is within 2 % of rest: the held incoming
    /// writes leave here.
    static let settle: TimeInterval = 0.28
    /// The landed writes' own time to show before the plates lift.
    static let landMargin: TimeInterval = 0.06
    /// The plates fade out over the landed windows.
    static let fadeOut: TimeInterval = 0.18

    /// A window clipped smaller than this on the page draws no
    /// plate: a stash corner's sliver, a scrolled-out column's edge.
    static let minimumSide: CGFloat = 24
    /// An icon smaller than this is dropped rather than drawn.
    static let iconMinimum: CGFloat = 20
    /// The icon's share of the plate's shorter side, and its cap.
    static let iconShare: CGFloat = 0.20
    static let iconMaximum: CGFloat = 96
    /// The plates' corner radius.
    static let cornerRadius: CGFloat = 16

    /// The axis the strip travels: across a top or bottom Space
    /// Bar, down a side one — the bar's own reading direction.
    enum Axis: Equatable {
        case horizontal, vertical
    }

    static func axis(spaceBarEdge: AppBarEdge) -> Axis {
        spaceBarEdge.isHorizontal ? .horizontal : .vertical
    }

    /// +1 when `to` comes after `from` in Space order, so its page
    /// enters from the trailing side; -1 the other way. Spaces the
    /// order does not hold compare as numbers, else +1.
    static func direction(
        from: SpaceID?,
        to: SpaceID,
        order: [SpaceID]
    ) -> CGFloat {
        guard let from, from != to else { return 1 }
        if let a = order.firstIndex(of: from),
            let b = order.firstIndex(of: to)
        {
            return a < b ? 1 : -1
        }
        if let a = Int(from.description), let b = Int(to.description) {
            return a < b ? 1 : -1
        }
        return 1
    }

    /// One window a page may show, in AX coordinates.
    struct Entry: Equatable {
        let id: WindowID
        let frame: CGRect
        let pid: pid_t
        /// In the float tier, which draws above the tiled plane.
        let floats: Bool
    }

    /// One plate: the part of its window the page shows, and the
    /// app whose icon it carries — only a pile's front face does.
    struct Plate: Equatable {
        let id: WindowID
        let frame: CGRect
        let iconPid: pid_t?
        /// Plates sharing a pile overlap; each pile is one glass
        /// container.
        let pile: Int
    }

    /// The plates for `entries` on the page `bounds`, back to front:
    /// tiled under floats, the focus last in its tier, else the
    /// WindowServer stack (`stack`: window number to its index,
    /// front first, read once at the press). One builder for both
    /// directions — the outgoing page reads frames now, the
    /// incoming one the frames the switch sent.
    static func plates(
        _ entries: [Entry],
        focus: WindowID?,
        stack: [UInt32: Int],
        in bounds: CGRect
    ) -> [Plate] {
        let clipped: [(Entry, CGRect)] = entries.compactMap {
            let inside = $0.frame.intersection(bounds)
            guard !inside.isNull, inside.width >= minimumSide,
                inside.height >= minimumSide
            else { return nil }
            return ($0, inside)
        }
        let ordered = clipped.sorted {
            key($0.0, focus, stack) < key($1.0, focus, stack)
        }
        // A plate wholly behind one in front of it shows nothing —
        // Monocle's stacked members, a pile's exact repeats.
        let shown = ordered.enumerated().filter { index, entry in
            !ordered[(index + 1)...].contains {
                $0.1.contains(entry.1)
            }
        }.map(\.element)
        let piles = pileIndices(shown.map(\.1))
        var faces: [Int: Int] = [:]
        for (index, entry) in shown.enumerated() {
            let pile = piles[index]
            if entry.0.id == focus {
                faces[pile] = index
            } else if faces[pile].map({ shown[$0].0.id != focus })
                ?? true
            {
                faces[pile] = index  // front-most so far
            }
        }
        return shown.enumerated().map { index, entry in
            Plate(
                id: entry.0.id,
                frame: entry.1,
                iconPid: faces[piles[index]] == index
                    ? entry.0.pid : nil,
                pile: piles[index]
            )
        }
    }

    /// The icon's side on a plate, nil where it would be smaller
    /// than `iconMinimum`.
    static func iconSide(on plate: CGRect) -> CGFloat? {
        let side = min(
            iconShare * min(plate.width, plate.height),
            iconMaximum
        )
        return side >= iconMinimum ? side : nil
    }

    /// Each plate's pile: overlapping plates share one, by a
    /// union over every overlapping pair.
    static func pileIndices(_ frames: [CGRect]) -> [Int] {
        var parent = Array(frames.indices)
        func root(_ i: Int) -> Int {
            var i = i
            while parent[i] != i { i = parent[i] }
            return i
        }
        for a in frames.indices {
            for b in frames.indices where b > a {
                let overlap = frames[a].intersection(frames[b])
                guard !overlap.isNull, overlap.width > 1,
                    overlap.height > 1
                else { continue }
                parent[root(b)] = root(a)
            }
        }
        var numbers: [Int: Int] = [:]
        return frames.indices.map {
            let r = root($0)
            if let n = numbers[r] { return n }
            numbers[r] = numbers.count
            return numbers[r]!
        }
    }

    private struct Key: Comparable {
        let tier: Int
        let focus: Int
        let depth: Int

        static func < (a: Key, b: Key) -> Bool {
            (a.tier, a.focus, a.depth) < (b.tier, b.focus, b.depth)
        }
    }

    private static func key(
        _ entry: Entry,
        _ focus: WindowID?,
        _ stack: [UInt32: Int]
    ) -> Key {
        Key(
            tier: entry.floats ? 1 : 0,
            focus: entry.id == focus ? 1 : 0,
            depth: -(stack[entry.id.raw] ?? Int.max)
        )
    }
}
