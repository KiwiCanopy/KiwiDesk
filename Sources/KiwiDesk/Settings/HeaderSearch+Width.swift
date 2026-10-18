import SwiftUI

/// The search field's width and the room from its leading edge to
/// the header's trailing edge, read in the header's own space.
struct SearchPanelRoom: Equatable {
    /// The header's coordinate space, named on its title row.
    static let headerSpace = "settings.header"

    var field: CGFloat = 0
    var room: CGFloat = 0

    /// The field's room as `proxy` reads it in the header's space.
    static func measured(by proxy: GeometryProxy) -> SearchPanelRoom {
        let space = NamedCoordinateSpace.named(headerSpace)
        let frame = proxy.frame(in: space)
        let header = proxy.bounds(of: space) ?? frame
        return SearchPanelRoom(
            field: frame.width,
            room: header.maxX - frame.minX
        )
    }
}

/// How wide the results panel draws (#2399): the field's width,
/// clamped, and never past the header's trailing edge.
enum SearchPanelWidth {
    /// The panel's width before #2399, kept as the floor.
    static let floor: CGFloat = 380
    /// Wider, a row's trailing value drifts from its title; the
    /// suggestion lists of Safari, Spotlight and Xcode are bounded.
    static let cap: CGFloat = 560

    /// The panel width for `room`; an unmeasured room (0) leaves
    /// the clamp alone.
    static func width(for room: SearchPanelRoom) -> CGFloat {
        let wanted = min(max(room.field, floor), cap)
        guard room.room > 0 else { return wanted }
        return min(wanted, room.room)
    }
}
