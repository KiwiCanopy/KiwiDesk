import CoreGraphics

extension ScreenShiftPlan {
    /// The farthest one move is tried, in points.
    static let searchLimit = 4000

    /// The ruled pick among every set of moves that frees every
    /// boxed-in screen: each step frees the first screen still
    /// boxed in, by any of its candidate moves, and the leaves are
    /// ranked whole. nil when no set frees them all.
    static func bestPlan(for screens: [ArrangedScreen]) -> [ScreenShift]? {
        let original = touchingPairs(screens)
        var best: (moves: [ScreenShift], rank: Rank)?
        func search(_ now: [ArrangedScreen], _ moves: [ScreenShift]) {
            guard
                let boxed = now.first(where: {
                    !hasFreeCorner($0, in: now)
                })
            else {
                let merged = merge(moves, over: original, in: screens)
                let rank = Rank(merged, original, screens)
                if best.map({ rank < $0.rank }) ?? true {
                    best = (merged, rank)
                }
                return
            }
            guard moves.count < screens.count else { return }
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

        init(
            _ moves: [ScreenShift],
            _ pairs: Set<Set<String>>,
            _ screens: [ArrangedScreen]
        ) {
            let moved = Set(moves.map(\.screen))
            crossings = pairs.filter { !$0.isDisjoint(with: moved) }.count
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

    /// One move per screen, its steps summed, each naming every
    /// screen it shared an edge with before the moves.
    static func merge(
        _ moves: [ScreenShift],
        over pairs: Set<Set<String>>,
        in screens: [ArrangedScreen]
    ) -> [ScreenShift] {
        let order = screens.map(\.id).filter { id in
            moves.contains { $0.screen == id }
        }
        return order.map { id in
            let delta = moves.filter { $0.screen == id }.reduce(
                CGVector.zero
            ) { CGVector(dx: $0.dx + $1.delta.dx, dy: $0.dy + $1.delta.dy) }
            let crossings = pairs.compactMap { pair -> String? in
                pair.contains(id) ? pair.first { $0 != id } : nil
            }
            return ScreenShift(
                screen: id,
                delta: delta,
                crossings: crossings.sorted()
            )
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
    /// away and keeps every touching pair touching.
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
        for step in 1...searchLimit {
            let delta = CGVector(
                dx: unit.dx * CGFloat(step),
                dy: unit.dy * CGFloat(step)
            )
            let after = screens.map {
                $0.id == id ? $0.moved(by: delta) : $0
            }
            guard
                let moved = after.first(where: { $0.id == boxed.id }),
                hasFreeCorner(moved, in: after),
                after.allSatisfy({
                    !hadFree.contains($0.id) || hasFreeCorner($0, in: after)
                }),
                pairs.isSubset(of: touchingPairs(after))
            else { continue }
            return ScreenShift(screen: id, delta: delta, crossings: [])
        }
        return nil
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

    /// Whether `other` sits to the side of `screen` rather than
    /// below it.
    static func beside(_ other: CGRect, _ screen: CGRect) -> Bool {
        (other.maxX <= screen.minX + 1 || other.minX >= screen.maxX - 1)
            && other.minY < screen.maxY
    }
}
