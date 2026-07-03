import CoreGraphics

/// Cardinal directions in AX coordinates (y grows downward).
public enum Direction: String, Sendable, Codable {
    case left
    case right
    case up
    case down
}

/// Geometric window navigation (`focus left`, `swap right`).
public enum Navigation {
    /// The nearest candidate whose center lies in `direction`
    /// from the origin frame. Lateral offset is penalized so
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
