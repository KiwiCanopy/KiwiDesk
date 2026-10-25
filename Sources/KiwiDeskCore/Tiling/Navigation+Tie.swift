import CoreGraphics

extension Navigation {
    /// How a directional step settles a tie (#2619): back to the
    /// window the last step left, else the first tied window in
    /// the Space's flat order. `.none` keeps the best score.
    public struct TieBreak: Sendable, Equatable {
        /// The window focused just before the origin; nil for a
        /// swap, which history never chooses.
        public var returnTo: WindowID?
        /// Flat index per window; empty where an order means
        /// nothing (another Space, the float tier).
        public var order: [WindowID: Int]

        public init(
            returnTo: WindowID? = nil,
            order: [WindowID: Int] = [:]
        ) {
            self.returnTo = returnTo
            self.order = order
        }

        public static let none = TieBreak()

        func resolve(_ tied: [WindowID]) -> WindowID? {
            if let returnTo, tied.contains(returnTo) {
                return returnTo
            }
            return
                tied
                .compactMap { id in order[id].map { (id, $0) } }
                .min { $0.1 < $1.1 }?.0
        }
    }

    /// The candidate in the track beside the origin whose center
    /// lies nearest the origin's on the cross axis, ties settled
    /// by `tie` — Track's step across tracks (#2619). Every
    /// candidate is one track, so none is nearer than another.
    public static func beside(
        _ origin: CGRect,
        crossIsY: Bool,
        candidates: [(id: WindowID, frame: CGRect)],
        tie: TieBreak = .none
    ) -> WindowID? {
        let scored = candidates.map { candidate in
            Scored(
                id: candidate.id,
                frame: candidate.frame,
                score: crossIsY
                    ? abs(candidate.frame.midY - origin.midY)
                    : abs(candidate.frame.midX - origin.midX),
                edge: 0
            )
        }
        return settle(scored, origin: origin, crossIsY: crossIsY, tie: tie)
    }

    struct Scored {
        let id: WindowID
        let frame: CGRect
        let score: CGFloat
        /// Distance from the origin's leading edge to the
        /// candidate's near edge.
        let edge: CGFloat
    }

    /// Slot arithmetic is exact, so these only absorb rounding.
    static let edgeTolerance: CGFloat = 2
    static let scoreTolerance: CGFloat = 0.5

    /// The best score, unless it ties: two or more of the
    /// nearest candidates lie wholly inside the origin's cross
    /// span, or two or more share the best score. A tie `tie`
    /// cannot settle keeps the best score.
    static func settle(
        _ scored: [Scored],
        origin: CGRect,
        crossIsY: Bool,
        tie: TieBreak
    ) -> WindowID? {
        guard let best = scored.min(by: { $0.score < $1.score })
        else { return nil }
        let nearest = scored.map(\.edge).min() ?? 0
        let (low, high) =
            crossIsY
            ? (origin.minY, origin.maxY) : (origin.minX, origin.maxX)
        let contained = scored.filter {
            let (a, b) =
                crossIsY
                ? ($0.frame.minY, $0.frame.maxY)
                : ($0.frame.minX, $0.frame.maxX)
            return $0.edge <= nearest + edgeTolerance
                && a >= low - edgeTolerance
                && b <= high + edgeTolerance
        }
        let tied =
            contained.count >= 2
            ? contained
            : scored.filter { $0.score <= best.score + scoreTolerance }
        guard tied.count >= 2 else { return best.id }
        return tie.resolve(tied.map(\.id)) ?? best.id
    }
}
