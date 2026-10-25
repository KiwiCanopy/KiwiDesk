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

    init() {}

    init(_ shelf: PanelHighlight, divider: String) {
        tinted = true
        selection = Color(kiwiHex: shelf.selection)
        selectionInk = Color(kiwiHex: shelf.selectionInk)
        selectionInkSecondary = selectionInk.opacity(0.75)
        rowHover = Color(kiwiHex: shelf.hover)
        chipHover = rowHover
        hoverInk = Color(kiwiHex: shelf.hoverInk)
        self.divider = Color(kiwiHex: divider)
    }

    /// The paint KiwiHub wears on `glass` as drawn, its divider from
    /// `ink`, the inks the panel chrome resolved for that glass.
    static func of(_ glass: PanelGlass, ink: PanelInk?) -> KiwiHubPaint {
        guard let shelf = glass.shelf, let ink else { return KiwiHubPaint() }
        return KiwiHubPaint(shelf.panelHighlight, divider: ink.divider)
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
