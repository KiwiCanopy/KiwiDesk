import Foundation

/// Sizing one run of a split (#3541): Even Out and the typed sizes
/// act on the row or column the selection sits in. A nested member
/// is resized by mapping its edges along the run's axis, so edges
/// its areas share stay shared and the tiling stays exact.
extension ScreenSplit {
    /// The split with `run`'s members laid out at `lengths`, in
    /// reading order, from the run's own start. Self where the
    /// counts differ or the lengths do not fill the run.
    public func resizing(
        _ run: ScreenAreaRun,
        to lengths: [Int]
    ) -> ScreenSplit {
        guard lengths.count == run.members.count,
            lengths.reduce(0, +) == run.lengths.reduce(0, +),
            let origin = run.members.first?.start
        else { return self }
        var copy = self
        var at = origin
        for (member, length) in zip(run.members, lengths) {
            let start = at
            at += length
            let map = { (p: Int) -> Int in
                Self.mapped(p, from: member, to: (start, length))
            }
            for index in copy.areas.indices
            where member.areas.contains(copy.areas[index].id) {
                var area = copy.areas[index]
                if run.axis == .sideBySide {
                    let lo = map(area.x)
                    area.w = map(area.x + area.w) - lo
                    area.x = lo
                } else {
                    let lo = map(area.y)
                    area.h = map(area.y + area.h) - lo
                    area.y = lo
                }
                copy.areas[index] = area
            }
        }
        return copy
    }

    /// `p`, inside `member`, at the same share of a member that
    /// starts at `to.0` and is `to.1` long; whole points, rounded.
    private static func mapped(
        _ p: Int,
        from member: ScreenAreaRun.Member,
        to: (start: Int, length: Int)
    ) -> Int {
        let length = max(member.length, 1)
        let offset = (p - member.start) * to.length
        return to.start + (2 * offset + length) / (2 * length)
    }

    /// The fewest points member `index` of `run` may take while
    /// every area in it keeps `floor` along the run's axis.
    public func memberFloor(
        of index: Int,
        in run: ScreenAreaRun,
        floor: Int
    ) -> Int {
        let member = run.members[index]
        let side = run.axis == .sideBySide
        let shortest =
            areas.filter { member.areas.contains($0.id) }
            .map { side ? $0.w : $0.h }.min() ?? member.length
        var least = Int(
            (Double(floor * member.length) / Double(max(shortest, 1)))
                .rounded(.up)
        )
        // Rounding the mapped edges can cost a point: step up to the
        // first length that keeps every area at the floor.
        while least < member.length,
            !keepsFloor(index, run, least, floor)
        {
            least += 1
        }
        return max(least, floor)
    }

    private func keepsFloor(
        _ index: Int,
        _ run: ScreenAreaRun,
        _ length: Int,
        _ floor: Int
    ) -> Bool {
        let member = run.members[index]
        let side = run.axis == .sideBySide
        return areas.filter { member.areas.contains($0.id) }.allSatisfy {
            let lo = Self.mapped(
                side ? $0.x : $0.y,
                from: member,
                to: (member.start, length)
            )
            let hi = Self.mapped(
                side ? $0.x + $0.w : $0.y + $0.h,
                from: member,
                to: (member.start, length)
            )
            return hi - lo >= floor
        }
    }

    /// The run holding `id` with every member as long as an even
    /// split makes it, odd points to the leading members, but none
    /// below its own floor (`memberFloor`): a member the even length
    /// would squeeze keeps its floor and the rest share what is left.
    /// Self where no such layout fits.
    public func evenedOut(
        holding id: Int,
        floor: Int
    ) -> ScreenSplit {
        guard let run = run(holding: id) else { return self }
        let floors = run.members.indices.map {
            memberFloor(of: $0, in: run, floor: floor)
        }
        var total = run.lengths.reduce(0, +)
        var fixed: [Int: Int] = [:]
        while true {
            let free = run.members.indices.filter { fixed[$0] == nil }
            guard !free.isEmpty else { return self }
            let share = total / free.count
            let squeezed = free.filter { floors[$0] > share }
            if squeezed.isEmpty {
                var lengths = Array(repeating: 0, count: floors.count)
                for (rank, index) in free.enumerated() {
                    lengths[index] =
                        share + (rank < total % free.count ? 1 : 0)
                }
                for (index, length) in fixed { lengths[index] = length }
                return resizing(run, to: lengths)
            }
            for index in squeezed {
                fixed[index] = floors[index]
                total -= floors[index]
            }
        }
    }

    /// Member `index` of `run` set to `length` points along its
    /// axis, member `other` giving way (#3517 ruling 26): one commit
    /// changes exactly these two members, the length clamped so
    /// each keeps the floor of every area in it. Nil where either
    /// index is out of the run or they are one member.
    public func setting(
        member index: Int,
        of run: ScreenAreaRun,
        to length: Int,
        givingWay other: Int,
        floor: Int
    ) -> (split: ScreenSplit, length: Int)? {
        guard index != other,
            run.members.indices.contains(index),
            run.members.indices.contains(other)
        else { return nil }
        var sizes = run.lengths
        let pair = sizes[index] + sizes[other]
        let low = memberFloor(of: index, in: run, floor: floor)
        let high = pair - memberFloor(of: other, in: run, floor: floor)
        guard low <= high else { return nil }
        let clamped = min(max(length, low), high)
        sizes[index] = clamped
        sizes[other] = pair - clamped
        return (resizing(run, to: sizes), clamped)
    }
}

extension ScreenSplit {
    /// How long `member`'s areas reach along `axis` in this split:
    /// its length after a resize that moved it.
    public func memberLength(
        _ member: ScreenAreaRun.Member,
        along axis: ScreenAreaCut.Axis
    ) -> Int {
        let inside = areas.filter { member.areas.contains($0.id) }
        let lo = inside.map { ScreenAreaRuns.lo($0, axis) }.min() ?? 0
        let hi = inside.map { ScreenAreaRuns.hi($0, axis) }.max() ?? 0
        return hi - lo
    }
}
