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
    /// straight neighbors beat diagonal ones.
    public static func neighbor(
        from origin: CGRect,
        in direction: Direction,
        candidates: [(id: WindowID, frame: CGRect)]
    ) -> WindowID? {
        let originCenter = CGPoint(
            x: origin.midX,
            y: origin.midY
        )
        var best: (id: WindowID, score: CGFloat)?
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
            switch direction {
            case .left:
                forward = -dx
                lateral = abs(dy)
            case .right:
                forward = dx
                lateral = abs(dy)
            case .up:
                forward = -dy
                lateral = abs(dx)
            case .down:
                forward = dy
                lateral = abs(dx)
            }
            guard forward > 0.5 else { continue }
            let score = forward + lateral * 2
            if best == nil || score < best!.score {
                best = (candidate.id, score)
            }
        }
        return best?.id
    }
}
