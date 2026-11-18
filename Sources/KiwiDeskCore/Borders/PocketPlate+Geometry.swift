import AppKit

/// Where the pocket stands inside its handle's panel (#2678): the
/// room past the outer margin and the risen pocket's frame in it,
/// split from `PocketPlateView` at the §2.1 ceiling.
extension PocketPlateView {
    /// The handle's room inside `bounds`, which reach the screen edge
    /// so a push to it still finds the handle: `outer` in from `edge`.
    static func room(
        in bounds: CGRect,
        edge: AppBarEdge,
        outer: CGFloat
    ) -> CGRect {
        var room = bounds
        switch edge {
        case .bottom: room.size.height -= outer
        case .top:
            room.origin.y += outer
            room.size.height -= outer
        case .left:
            room.origin.x += outer
            room.size.width -= outer
        case .right: room.size.width -= outer
        }
        return room
    }

    /// Where the risen pocket stands inside the handle's room: on its
    /// centre line, its base `lift` past the tab (#2678).
    static func risenFrame(
        in bounds: CGRect,
        edge: AppBarEdge,
        side: CGFloat,
        tabDepth: CGFloat
    ) -> CGRect {
        let gap = tabDepth + lift
        let x: CGFloat
        let y: CGFloat
        switch edge {
        case .bottom:
            x = bounds.midX - side / 2
            y = bounds.maxY - gap - side
        case .top:
            x = bounds.midX - side / 2
            y = bounds.minY + gap
        case .left:
            x = bounds.minX + gap
            y = bounds.midY - side / 2
        case .right:
            x = bounds.maxX - gap - side
            y = bounds.midY - side / 2
        }
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// The risen pocket's clearance past the tab.
    static let lift: CGFloat = 4
}
