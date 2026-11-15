import CoreGraphics

extension ScreenShiftPlan {
    /// The farthest one move is tried, in points.
    static let searchLimit = 4000

    /// The ruled pick among every set of moves that frees every
    /// boxed-in screen: each step frees the first screen still
    /// boxed in, by any of its candidate moves, and the leaves are
    /// ranked whole. nil when no set frees them all. Each step
    /// frees a screen and boxes in none, so the depth is at most
    /// the number of boxed-in screens.
    static func bestPlan(for screens: [ArrangedScreen]) -> [ScreenShift]? {
        var best: (moves: [ScreenShift], rank: Rank)?
        func search(_ now: [ArrangedScreen], _ moves: [ScreenShift]) {
            guard
                let boxed = now.first(where: {
                    !hasFreeCorner($0, in: now)
                })
            else {
                let merged = merge(moves, in: screens)
                let rank = Rank(merged, screens)
                if best.map({ rank < $0.rank }) ?? true {
                    best = (merged, rank)
                }
                return
            }
            for candidate in candidates(freeing: boxed, in: now) {
                guard
                    let move = shortest(
                        moving: candidate.id,
                        along: candidate.unit,
                        freeing: boxed,
                        in: now
                    )
                else { continue }
                let next = now.map {
                    $0.id == move.screen ? $0.moved(by: move.delta) : $0
                }
                search(next, moves + [move])
            }
        }
        search(screens, [])
        return best?.moves
    }

    /// The pick's order: crossings changed over the whole
    /// arrangement, then a main screen last, since moving it moves
    /// every other screen's origin, then total distance.
    struct Rank: Comparable {
        let crossings: Int
        let movesMain: Int
        let distance: CGFloat

        init(_ moves: [ScreenShift], _ screens: [ArrangedScreen]) {
            let moved = Set(moves.map(\.screen))
            crossings = moves.reduce(0) { $0 + $1.crossings.count }
            movesMain =
                screens.contains { $0.isMain && moved.contains($0.id) }
                ? 1 : 0
            distance = moves.reduce(0) {
                $0 + abs($1.delta.dx) + abs($1.delta.dy)
            }
        }

        static func < (a: Rank, b: Rank) -> Bool {
            (a.crossings, a.movesMain, a.distance)
                < (b.crossings, b.movesMain, b.distance)
        }
    }

    /// One move per screen, its steps summed. Each shared edge the
    /// moves shift is listed once, under the first moved screen of
    /// its pair, with the two screens' relative move along it: two
    /// screens moving together shift no crossing.
    static func merge(
        _ moves: [ScreenShift],
        in screens: [ArrangedScreen]
    ) -> [ScreenShift] {
        var deltas: [String: CGVector] = [:]
        for move in moves {
            let sum = deltas[move.screen] ?? .zero
            deltas[move.screen] = CGVector(
                dx: sum.dx + move.delta.dx,
                dy: sum.dy + move.delta.dy
            )
        }
        let order = screens.map(\.id).filter { deltas[$0] != nil }
        var listed: Set<Set<String>> = []
        return order.map { id in
            let own = deltas[id] ?? .zero
            var crossings: [ScreenCrossing] = []
            for other in screens where other.id != id {
                let pair: Set<String> = [id, other.id]
                guard
                    !listed.contains(pair),
                    let me = screens.first(where: { $0.id == id }),
                    touches(me.frame, other.frame)
                else { continue }
                let theirs = deltas[other.id] ?? .zero
                let sideBySide = sideBySide(me.frame, other.frame)
                let along = CGVector(
                    dx: sideBySide ? 0 : own.dx - theirs.dx,
                    dy: sideBySide ? own.dy - theirs.dy : 0
                )
                listed.insert(pair)
                guard along != .zero else { continue }
                crossings.append(
                    ScreenCrossing(screen: other.id, delta: along)
                )
            }
            return ScreenShift(screen: id, delta: own, crossings: crossings)
        }
    }

    /// Each screen that may move, with the direction it moves in:
    /// the boxed-in screen down, a side neighbour at a covered
    /// corner up, a screen below sideways away from the corner it
    /// covers (both ways where it covers both).
    static func candidates(
        freeing boxed: ArrangedScreen,
        in screens: [ArrangedScreen]
    ) -> [(id: String, unit: CGVector)] {
        var found: [(id: String, unit: CGVector)] = [
            (boxed.id, CGVector(dx: 0, dy: 1))
        ]
        let left = coverer(of: boxed, at: .bottomLeft, in: screens)
        let right = coverer(of: boxed, at: .bottomRight, in: screens)
        for id in Set([left, right].compactMap { $0 }).sorted() {
            guard let other = screens.first(where: { $0.id == id })
            else { continue }
            if beside(other.frame, boxed.frame) {
                found.append((id, CGVector(dx: 0, dy: -1)))
                continue
            }
            if id == left { found.append((id, CGVector(dx: 1, dy: 0))) }
            if id == right {
                found.append((id, CGVector(dx: -1, dy: 0)))
            }
        }
        return found
    }

    /// The smallest whole-point move of `id` along `unit` that
    /// frees a corner of `boxed`, takes no screen's free corner
    /// away, keeps exactly the touching pairs there were and lays
    /// no screen over another. A pair pulled apart stays apart as
    /// the move goes on, so the search stops there.
    static func shortest(
        moving id: String,
        along unit: CGVector,
        freeing boxed: ArrangedScreen,
        in screens: [ArrangedScreen]
    ) -> ScreenShift? {
        let hadFree = Set(
            screens.filter { hasFreeCorner($0, in: screens) }.map(\.id)
        )
        let pairs = touchingPairs(screens)
        let overlapping = overlappingPairs(screens)
        for step in 1...searchLimit {
            let delta = CGVector(
                dx: unit.dx * CGFloat(step),
                dy: unit.dy * CGFloat(step)
            )
            let after = screens.map {
                $0.id == id ? $0.moved(by: delta) : $0
            }
            let now = touchingPairs(after)
            // An early stop, no rule: the `now == pairs` check
            // below refuses the same steps, a step at a time.
            guard pairs.isSubset(of: now) else { return nil }
            guard
                now == pairs,
                overlappingPairs(after) == overlapping,
                let moved = after.first(where: { $0.id == boxed.id }),
                hasFreeCorner(moved, in: after),
                after.allSatisfy({
                    !hadFree.contains($0.id) || hasFreeCorner($0, in: after)
                })
            else { continue }
            return ScreenShift(screen: id, delta: delta, crossings: [])
        }
        return nil
    }

    /// Whether any two screens share an area, which macOS would
    /// resolve by rearranging them itself.
    static func overlaps(_ screens: [ArrangedScreen]) -> Bool {
        !overlappingPairs(screens).isEmpty
    }

    /// Every pair sharing an area. A step may keep one there
    /// already, a mirror, but never makes a new one.
    static func overlappingPairs(
        _ screens: [ArrangedScreen]
    ) -> Set<Set<String>> {
        var pairs: Set<Set<String>> = []
        for (index, a) in screens.enumerated() {
            for b in screens.dropFirst(index + 1)
            where !a.frame.intersection(b.frame).isEmpty {
                pairs.insert([a.id, b.id])
            }
        }
        return pairs
    }

    /// Every pair of screens that touch, as two-element sets.
    static func touchingPairs(
        _ screens: [ArrangedScreen]
    ) -> Set<Set<String>> {
        var pairs: Set<Set<String>> = []
        for (index, a) in screens.enumerated() {
            for b in screens.dropFirst(index + 1)
            where touches(a.frame, b.frame) {
                pairs.insert([a.id, b.id])
            }
        }
        return pairs
    }

    /// Whether two touching screens meet at a vertical edge.
    static func sideBySide(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.maxX - b.minX) <= 1 || abs(b.maxX - a.minX) <= 1
    }

    /// Whether `other` sits to the side of `screen` rather than
    /// below it.
    static func beside(_ other: CGRect, _ screen: CGRect) -> Bool {
        (other.maxX <= screen.minX + 1 || other.minX >= screen.maxX - 1)
            && other.minY < screen.maxY
    }
}
