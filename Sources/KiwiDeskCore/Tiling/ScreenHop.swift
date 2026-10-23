import CoreGraphics

/// Which screen lies which way (#2493, #2512), as pure geometry
/// over AX frames. A screen counts only where it overlaps `band`
/// on the cross axis — the vertical extent for ←/→, the
/// horizontal for ↑/↓ — so a diagonal screen is no neighbour.
public enum ScreenHop {
    public typealias Screen = (id: DisplayID, frame: CGRect)

    /// Slack for screens that touch: macOS lays them edge to edge.
    static let touch: CGFloat = 1

    /// The screens past `current` in `direction`, overlapping
    /// `band`, nearest first.
    public static func ahead(
        of current: CGRect,
        in direction: Direction,
        band: CGRect,
        among screens: [Screen]
    ) -> [DisplayID] {
        screens.filter {
            overlaps($0.frame, band, direction)
                && gap(from: current, to: $0.frame, direction) >= -touch
        }
        .sorted {
            gap(from: current, to: $0.frame, direction)
                < gap(from: current, to: $1.frame, direction)
        }
        .map(\.id)
    }

    /// The order a focus key tries screens in at its last window:
    /// the screens ahead, nearest first, then — wrapping around —
    /// those on the opposite side, farthest first. `current` is
    /// never listed; it is the wrap's last resort.
    public static func hopOrder(
        from current: DisplayID,
        in direction: Direction,
        band: CGRect,
        among screens: [Screen]
    ) -> [DisplayID] {
        guard let here = screens.first(where: { $0.id == current })
        else { return [] }
        let others = screens.filter { $0.id != current }
        let forward = ahead(
            of: here.frame,
            in: direction,
            band: band,
            among: others
        )
        let back = ahead(
            of: here.frame,
            in: direction.opposite,
            band: band,
            among: others
        )
        return forward + back.reversed()
    }

    /// A thin origin just outside `bounds` on the edge a step in
    /// `direction` enters through, at `band`'s cross position —
    /// what `Navigation.neighbor` is seeded from to find the
    /// window nearest that edge.
    public static func entrySeed(
        into bounds: CGRect,
        entering direction: Direction,
        band: CGRect
    ) -> CGRect {
        switch direction {
        case .right:
            CGRect(
                x: bounds.minX - 2,
                y: band.minY,
                width: 1,
                height: band.height
            )
        case .left:
            CGRect(
                x: bounds.maxX + 1,
                y: band.minY,
                width: 1,
                height: band.height
            )
        case .down:
            CGRect(
                x: band.minX,
                y: bounds.minY - 2,
                width: band.width,
                height: 1
            )
        case .up:
            CGRect(
                x: band.minX,
                y: bounds.maxY + 1,
                width: band.width,
                height: 1
            )
        }
    }

    /// Whether `screen` overlaps `band` across `direction`.
    static func overlaps(
        _ screen: CGRect,
        _ band: CGRect,
        _ direction: Direction
    ) -> Bool {
        switch direction {
        case .left, .right:
            screen.maxY > band.minY && screen.minY < band.maxY
        case .up, .down:
            screen.maxX > band.minX && screen.minX < band.maxX
        }
    }

    /// How far `next` begins past `current`'s edge in `direction`;
    /// negative where it does not lie that way.
    static func gap(
        from current: CGRect,
        to next: CGRect,
        _ direction: Direction
    ) -> CGFloat {
        switch direction {
        case .right: next.minX - current.maxX
        case .left: current.minX - next.maxX
        case .down: next.minY - current.maxY
        case .up: current.minY - next.maxY
        }
    }
}

extension Direction {
    /// The way back.
    public var opposite: Direction {
        switch self {
        case .left: .right
        case .right: .left
        case .up: .down
        case .down: .up
        }
    }
}
