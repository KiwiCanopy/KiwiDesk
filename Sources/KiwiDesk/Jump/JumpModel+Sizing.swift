import CoreGraphics
import KiwiDeskCore

/// Each side's width in the room the panel opened in (#3570): the
/// side reports what its content asks, and `JumpPanelRoom` clamps
/// it to the side's limits.
extension JumpModel {
    /// The panel's width on the shown side.
    var sideWidth: CGFloat { sideWidth(for: scope) }

    func sideWidth(for scope: JumpScope) -> CGFloat {
        room.width(
            JumpPanelRoom.fit(of: scope),
            content: contentWidth(for: scope)
        )
    }

    /// The width a side's content asks for, before the room clamps
    /// it; a compact side asks for the field row's.
    func contentWidth(for scope: JumpScope) -> CGFloat {
        switch scope {
        case .windows, .view: return room.fieldWidth
        case .shortcuts:
            return ShortcutsColumnPlan.width(
                columns: shortcutCount ?? 1,
                inset: JumpShortcutsView.kiwiHubInset,
                gap: ShortcutsSheetView.columnGap
            )
        case .desktops: return desktopsContentWidth
        }
    }

    /// The Desktops side's own width: one narrowest column per
    /// screen (#3570 ▸ Ruling 4), the field row's before it loads.
    var desktopsContentWidth: CGFloat {
        desktops.map { DesktopsGeometry.preferredWidth(of: $0.overview) }
            ?? room.fieldWidth
    }
}
