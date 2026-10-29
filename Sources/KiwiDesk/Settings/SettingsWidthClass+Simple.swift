import CoreGraphics

/// Simple's two columns where a panel docks (#2737 ruling 10, as
/// re-ruled 2026-10-29): the controls take a share of the window
/// between two bounds, the preview's desk grows to what the rest of
/// the width and the window's height allow, and what is left over
/// is split as equal margins, centring the pair. Whether it docks is
/// `SettingsPreviewForm`'s; the save pill centres against `preview`
/// through `SettingsView.dockedPanelWidth`.
struct SimpleColumns: Equatable {
    /// The controls column, insets included.
    var controls: CGFloat
    /// The preview column: the plate and its insets.
    var preview: CGFloat
    /// Each outer margin.
    var margin: CGFloat
    /// The desk plate the preview draws.
    var plate: CGSize

    /// The controls' content cap, so a wide window does not
    /// stretch the rows.
    static let contentCap: CGFloat = 760
    /// The controls column's share of the window and its bounds:
    /// 580 at the docking width, the content cap plus insets wide.
    static let controlsShare: CGFloat = 0.48
    static let controlsMin: CGFloat = 580
    static let controlsMax = contentCap + 2 * SettingsMetrics.paneInset
    /// The widest plate; past it the margins grow instead.
    static let plateCap: CGFloat = 1200
    /// The preview column's horizontal inset, each side.
    static let previewInset: CGFloat = 22
    /// The plate's padding around the bars tile, each side.
    static let platePadding: CGFloat = 12
    /// The bars tile's aspect (`HomeCardBarsTile`).
    static let aspect: CGFloat = 16.0 / 10.0
    /// The preview's top gutter and the spacing between its parts.
    static let previewTop: CGFloat = 24
    static let spacing: CGFloat = 14
    /// The screen map's height, drawn on 2+ screens.
    static let mapHeight: CGFloat = 96
    /// What the preview column draws besides the plate: the
    /// gutters, the header line and two caption lines' room, kept
    /// so a hover's caption never resizes the plate.
    static let chromeHeight: CGFloat =
        2 * previewTop + 13 + 2 * spacing + 30
    /// The bars' scale at the tile width it was tuned on.
    static let barScale: CGFloat = 1.8
    static let barScaleTileWidth: CGFloat = 441.6

    /// The columns for a pane of `size`, `drawsMap` when the
    /// preview shows the screen map below the plate.
    static func of(_ size: CGSize, drawsMap: Bool) -> SimpleColumns {
        let controls = min(
            max(size.width * controlsShare, controlsMin),
            controlsMax
        )
        let room = max(0, size.width - controls - 1)
        let heightRoom =
            size.height - chromeHeight
            - (drawsMap ? spacing + mapHeight : 0)
        let pad = 2 * platePadding
        let byHeight = max(0, heightRoom - pad) * aspect + pad
        let plateWidth = max(
            pad,
            min(room - 2 * previewInset, byHeight, plateCap)
        )
        let preview = plateWidth + 2 * previewInset
        return SimpleColumns(
            controls: controls,
            preview: preview,
            margin: max(0, (room - preview) / 2),
            plate: CGSize(
                width: plateWidth,
                height: (plateWidth - pad) / aspect + pad
            )
        )
    }

    /// The bars' scale for this plate, so a larger desk draws its
    /// bars larger rather than as hairlines.
    var barScale: CGFloat {
        let tile = plate.width - 2 * Self.platePadding
        return Self.barScale * tile / Self.barScaleTileWidth
    }
}
