import CoreGraphics

/// Cardinal directions in AX coordinates (y grows downward).
public enum Direction: String, Sendable, Codable, CaseIterable {
    case left
    case right
    case up
    case down
}

/// Geometric window navigation (`focus left`, `swap right`).
public enum Navigation {
    /// Nearest candidate whose center lies in `direction`.
    /// Candidates must overlap the origin on the cross axis —
    /// otherwise a full-height master would jump diagonally
    /// into the stack — and lateral offset is penalized so
    /// straight neighbors beat diagonal ones. A tie goes to
    /// `tie` (#2619).
    public static func neighbor(
        from origin: CGRect,
        in direction: Direction,
        candidates: [(id: WindowID, frame: CGRect)],
        tie: TieBreak = .none
    ) -> WindowID? {
        let originCenter = CGPoint(
            x: origin.midX,
            y: origin.midY
        )
        var scored: [Scored] = []
        for candidate in candidates {
            switch direction {
            case .left, .right:
                guard candidate.frame.maxY > origin.minY,
                    candidate.frame.minY < origin.maxY
                else { continue }
            case .up, .down:
                guard candidate.frame.maxX > origin.minX,
                    candidate.frame.minX < origin.maxX
                else { continue }
            }
            let center = CGPoint(
                x: candidate.frame.midX,
                y: candidate.frame.midY
            )
            let dx = center.x - originCenter.x
            let dy = center.y - originCenter.y
            let forward: CGFloat
            let lateral: CGFloat
            let edge: CGFloat
            switch direction {
            case .left:
                forward = -dx
                lateral = abs(dy)
                edge = origin.minX - candidate.frame.maxX
            case .right:
                forward = dx
                lateral = abs(dy)
                edge = candidate.frame.minX - origin.maxX
            case .up:
                forward = -dy
                lateral = abs(dx)
                edge = origin.minY - candidate.frame.maxY
            case .down:
                forward = dy
                lateral = abs(dx)
                edge = candidate.frame.minY - origin.maxY
            }
            guard forward > 0.5 else { continue }
            scored.append(
                Scored(
                    id: candidate.id,
                    frame: candidate.frame,
                    score: forward + lateral * 2,
                    edge: edge
                )
            )
        }
        return settle(
            scored,
            origin: origin,
            crossIsY: direction == .left || direction == .right,
            tie: tie
        )
    }
}
