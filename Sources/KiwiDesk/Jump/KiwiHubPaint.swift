import KiwiDeskCore
import SwiftUI

/// KiwiHub's selection and hover (#2569): kiwi green by default,
/// KiwiShelf's highlight and hover fill under "Tint KiwiHub and
/// plates" (`KiwiShelf.panelHighlight`). Rows, chips and tiles read
/// it from the environment the panel sets once.
struct KiwiHubPaint {
    var selection = SettingsTheme.accent
    var selectionInk = SettingsTheme.accentInk
    var selectionInkSecondary = SettingsTheme.accentInkSecondary
    /// A hovered row's or tile's ground, and a hovered chip's.
    var rowHover = SettingsTheme.chipRest
    var chipHover = SettingsTheme.chipHover
    /// A hovered item's ink; nil keeps the item's own.
    var hoverInk: Color?
    /// Whether the shelf paints KiwiHub (the toggle is on).
    var tinted = false
    /// A divider's hairline under the toggle (#2596); nil keeps the
    /// system separator.
    var divider: Color?
    /// The panel Fill as its glass paints it, whose direction a
    /// selection or hover fill follows (#2721); nil draws it flat.
    var fade: GlassPaint?
    /// The far end of a faded fill as a share of its top
    /// (`KiwiShelf.highlightFadeShare(increaseContrast:)`).
    var share: CGFloat = 1

    init() {}

    init(
        _ shelf: PanelHighlight,
        divider: String,
        fade: GlassPaint? = nil,
        share: CGFloat = 1
    ) {
        tinted = true
        selection = Color(kiwiHex: shelf.selection)
        selectionInk = Color(kiwiHex: shelf.selectionInk)
        selectionInkSecondary = selectionInk.opacity(0.75)
        rowHover = Color(kiwiHex: shelf.hover)
        chipHover = rowHover
        hoverInk = Color(kiwiHex: shelf.hoverInk)
        self.divider = Color(kiwiHex: divider)
        self.fade = fade
        self.share = share
    }

    /// The paint KiwiHub wears on `glass` as drawn, its divider from
    /// `ink`, the inks the panel chrome resolved for that glass;
    /// its fills fade along `tint`, the glass's own paint, to the
    /// shelf's highlight share under `increaseContrast`.
    static func of(
        _ glass: PanelGlass,
        ink: PanelInk?,
        tint: GlassPaint? = nil,
        increaseContrast: Bool = false
    ) -> KiwiHubPaint {
        guard let shelf = glass.shelf, let ink else { return KiwiHubPaint() }
        return KiwiHubPaint(
            shelf.panelHighlight,
            divider: ink.divider,
            fade: tint,
            share: shelf.highlightFadeShare(
                increaseContrast: increaseContrast
            )
        )
    }

    /// The far end of a faded fill as a share of its top; nil
    /// draws it flat, off the toggle or with no fade.
    var fadeShare: CGFloat? {
        guard fade != nil, share < 1 else { return nil }
        return share
    }
}

/// A KiwiHub divider: the look's hairline under the toggle, the
/// system separator off it (#2596).
struct PanelDivider: View {
    @Environment(\.kiwiHubPaint) private var paint

    var body: some View {
        if let hairline = paint.divider {
            Rectangle().fill(hairline).frame(height: 1)
        } else {
            Divider()
        }
    }
}

extension KiwiHubPaint {
    /// `color` as a selection, hover or track fill: faded along
    /// the panel's Fill to `fadeShare`; flat off the toggle.
    func fill(_ color: Color) -> AnyShapeStyle {
        guard let fade, let fadeShare else { return AnyShapeStyle(color) }
        return AnyShapeStyle(
            LinearGradient(
                colors: [color, color.opacity(fadeShare)],
                startPoint: UnitPoint(x: fade.start.x, y: fade.start.y),
                endPoint: UnitPoint(x: fade.end.x, y: fade.end.y)
            )
        )
    }

    /// The ink a selected or hovered item's every level takes under
    /// the toggle; nil leaves the panel's own (#2569).
    func rowInk(selected: Bool, lifted: Bool) -> Color? {
        guard tinted else { return nil }
        if selected { return selectionInk }
        return lifted ? hoverInk : nil
    }
}

extension View {
    /// A selected or hovered KiwiHub item's three ink levels, all
    /// from its own ink, so no caption keeps the panel's Item ink on
    /// the highlight (#2569).
    @ViewBuilder
    func kiwiHubRowInk(
        _ paint: KiwiHubPaint,
        selected: Bool,
        lifted: Bool
    ) -> some View {
        if let ink = paint.rowInk(selected: selected, lifted: lifted) {
            foregroundStyle(ink, ink.opacity(0.75), ink.opacity(0.6))
        } else {
            self
        }
    }
}

extension EnvironmentValues {
    @Entry var kiwiHubPaint = KiwiHubPaint()
}
