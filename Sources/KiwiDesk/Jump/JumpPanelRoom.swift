import CoreGraphics
import KiwiDeskCore

/// Where KiwiHub may stand and how big each side may grow there
/// (#3570 ▸ Ruling): the field row fixed at 720 pt, centred at
/// `topFraction`; Windows and View at most 720 × 488; Desktops and
/// Shortcuts as wide as their content asks, 96 pt clear of each
/// side, and down to 48 pt above the area's bottom. The panel is
/// never lifted. Pure, so every caller hands it the rect it fits —
/// a screen's clear area, or one screen area's (#3572).
struct JumpPanelRoom: Equatable {
    /// The rect the panel fits, KiwiShelf strips cut away
    /// (`JumpPanelController.clearArea`).
    let area: CGRect
    /// The field row's top edge, in `area`'s coordinates.
    let top: CGFloat

    /// How a side sizes itself.
    enum Sizing: Equatable {
        /// 720 pt wide and at most `compactHeight` tall.
        case compact
        /// As wide and tall as the content asks, up to the room.
        case grows
    }

    /// The field row's width and every side's least width.
    static let fieldWidth: CGFloat = 720
    /// A compact side's tallest panel: room for the Windows side's
    /// nine rows under the footer row (#2309, raised for #1229).
    static let compactHeight: CGFloat = 488
    /// A growing side's clearance from each side of the area.
    static let sideMargin: CGFloat = 96
    /// A growing side's clearance above the area's bottom.
    static let bottomMargin: CGFloat = 48
    /// A narrow area's clearance on each side, for the field row.
    static let narrowMargin: CGFloat = 40

    /// `visible` is the frame `topFraction` measures the field's
    /// height on: the screen's visible frame, or the screen area's
    /// share of it.
    init(visible: CGRect, area: CGRect, topFraction: CGFloat) {
        self.area = area
        top = visible.maxY - visible.height * topFraction
    }

    static func sizing(of scope: JumpScope) -> Sizing {
        switch scope {
        case .windows, .view: return .compact
        case .shortcuts, .desktops: return .grows
        }
    }

    /// The field row's width: 720 pt, kept `narrowMargin` clear
    /// of each edge of a narrower area.
    var fieldWidth: CGFloat {
        max(min(Self.fieldWidth, area.width - 2 * Self.narrowMargin), 0)
    }

    /// The widest a growing side stands.
    var widest: CGFloat {
        max(area.width - 2 * Self.sideMargin, fieldWidth)
    }

    /// The panel's width for a side whose content asks for
    /// `content` points: never narrower than the field row.
    func width(_ sizing: Sizing, content: CGFloat) -> CGFloat {
        switch sizing {
        case .compact: return fieldWidth
        case .grows: return min(max(content, fieldWidth), widest)
        }
    }

    /// The panel's tallest, field to footer.
    func height(_ sizing: Sizing) -> CGFloat {
        let below = top - area.minY
        switch sizing {
        case .compact:
            return max(min(below - Self.narrowMargin, Self.compactHeight), 0)
        case .grows:
            return max(below - Self.bottomMargin, 0)
        }
    }

    /// The panel's origin for `size`: centred across the area, its
    /// top at the field's line, never lifted.
    func origin(of size: CGSize) -> CGPoint {
        CGPoint(x: area.midX - size.width / 2, y: top - size.height)
    }

    /// A panel `size` big whose top edge's midpoint is `anchor`:
    /// the field row's place, held across every refit.
    static func frame(of size: CGSize, under anchor: CGPoint) -> CGRect {
        CGRect(
            x: anchor.x - size.width / 2,
            y: anchor.y - size.height,
            width: size.width,
            height: size.height
        )
    }
}
