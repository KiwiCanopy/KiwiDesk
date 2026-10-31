import CoreGraphics
import KiwiDeskCore
import SwiftUI

/// Schematic preview of the shelf and the bars on it (#793, owner
/// 2026-08-10, #1517): one strip on the shelf's edge, the bars
/// placed by Core's `ShelfArrangement`. Not modelled: the margins
/// and the outer gap (#1516) — a few points draw as nothing at
/// this scale — the identifier tint
/// flag, a schematic dims nothing (#1538), and a second host's
/// own App Bar look: the frame draws the first host's.
struct HomeCardBarsTile: View {
    let settings: TilingSettings
    /// Whether the pocket stands on the shelf, Core's
    /// `pocketStands` at rest: Several windows (#2678).
    let pocketStands: Bool
    /// Real space count from draft (owner 2026-08-10).
    var spaceCount: Int = 3
    /// Scale factor (1 on home plate, larger in detail panel).
    var scale: CGFloat = 1
    /// Space identifiers for panel scale rendering — Core's own
    /// verdict per Space (#1538).
    var spaceLabels: [SpaceGlyph] = []
    /// Which Space item draws as current (Simple's Space cards,
    /// #2777); the first elsewhere.
    var activeSpace = 0
    /// Whether this frame draws the App Bar — false for the
    /// layouts that host none, where the Space Bar is alone.
    var showsAppBar = true
    /// Drawn inside the desktop's well, so it sits clear of the
    /// shelf on any edge and scales with the frame (a look card's
    /// focused window, #1739).
    var wellContent: AnyView?
    /// The App Bar's items drawn as real app art, one per item and
    /// no title (a look's picture, #1740); nil draws the mocks.
    var appArt: [BarArt]?
    /// Whether the frame and the well draw their schematic chrome;
    /// a look's picture draws its own ground beneath (#1740).
    var drawsChrome = true
    @Environment(\.schematicPalette) private var palette

    /// An App Bar item's art (#1740): an app's own icon, or its
    /// App Font ligature in the item's ink.
    enum BarArt {
        case icon(NSImage)
        case appFont(String)
    }

    struct BarItem {
        var color: String
        var length: CGFloat
        var label: String?
        var glyph: String?
        /// The glyph's size against `BarSpec.fontSize`: the App
        /// Bar's icon steps down by Core's slot ratio, a Space's
        /// symbol identifier draws at the identifier size.
        var glyphRatio: CGFloat = AppBarStyle.glyphSlotRatio
        var art: BarArt?
        var active = false
    }

    struct BarSpec {
        var fill: String
        var highlight: String
        var items: [BarItem]
        var alignment: AppBarStyle.BarAlignment
        var spans: Bool
        /// Boxes per item and no plate: `KiwiShelf.drawsPlate`.
        var boxed: Bool
        var thickness: CGFloat
        var corner: CGFloat
        var itemCorner: CGFloat
        var gap: CGFloat
        var indicator: AppBarStyle.ActiveIndicator
        /// The outline's stroke and the edge mark's thickness at
        /// the frame's scale (`indicatorWidths`, #1680).
        var outlineWidth: CGFloat
        var edgeMarkWidth: CGFloat
        /// The shelf's border at the frame's scale, 0 while off
        /// (`borderWidth(_:)`, #1679), and its colour.
        var borderWidth: CGFloat
        var borderColor: String
        var fontSize: CGFloat
        /// The share of the thickness the content fills
        /// (`contentShare`, #1682).
        var contentShare: CGFloat = 1
        /// The shelf the text is drawn from (#1681): the strip asks
        /// its own `textFont`, as the live bar does
        /// (`HomeCardPlate+BarFont.swift`).
        var shelf: KiwiShelf
        /// Whether the sheen paints the indicator and the border
        /// (#1644) — its own value, no other gate.
        var sheen: CGFloat
        /// The App Bar's title cap, whose slot every title draws
        /// in as the live bar's (`BarTitleSlot`, #2545); nil for
        /// the Space Bar, whose labels size to themselves.
        var titleCap: Int? = nil
    }

    /// The share of the thickness an item's content fills, read
    /// off Core's `contentDepth(forDepth:)` (#1682), so the
    /// frame's glyphs follow the glyph size as the live bar's.
    func contentShare(_ shelf: KiwiShelf) -> CGFloat {
        guard shelf.thickness > 0 else { return 1 }
        return shelf.contentDepth(forDepth: shelf.thickness)
            / shelf.thickness
    }

    /// A labelled pip's padding along a horizontal and a vertical
    /// bar, at one `scale`: `BarStripView.pipBody` draws it and an
    /// art item's length reads it.
    static let pipPad = (horizontal: CGFloat(2.5), vertical: CGFloat(1.5))

    /// Schematic points per live point of an indicator: the
    /// frame draws the shipped 2 pt ring at one `scale`.
    static let indicatorPerPoint: CGFloat = 0.5

    /// The indicator's two weights for this frame, read off the
    /// shelf's own width and Core's edge-mark derivation (#1680).
    func indicatorWidths(
        _ shelf: KiwiShelf
    ) -> (outline: CGFloat, edgeMark: CGFloat) {
        let unit = Self.indicatorPerPoint * scale
        return (
            max(1, shelf.resolvedHighlightWidth * unit),
            shelf.edgeMarkThickness * unit
        )
    }

    /// The border's stroke for this frame: the shelf's drawn
    /// width at the indicators' scale, so a live 1 pt border
    /// reads beside the 2 pt ring as it does on the bar (#1679).
    func borderWidth(_ shelf: KiwiShelf) -> CGFloat {
        shelf.drawnBorderWidth * Self.indicatorPerPoint * scale
    }

    /// The App Bar the preview draws: the first layout whose bar
    /// is not hidden (#761), or nil when none is.
    private var appBarLook: AppBarLook? {
        Self.appBarMode(settings).flatMap { settings.appBarHost(for: $0) }
            .map { settings.appBarLook(for: $0.appBar) }
    }

    /// The layout whose App Bar the preview draws: the first whose
    /// bar is not hidden (#761), or nil when none is.
    static func appBarMode(_ settings: TilingSettings) -> LayoutMode? {
        LayoutMode.allCases.first {
            settings.appBarHost(for: $0)?.appBar.visibility
                .showsUnprompted == true
        }
    }

    var body: some View {
        Group {
            if rowsRunFullWidth { rowsOuter } else { columnsOuter }
        }
        .padding(3)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(
                    palette?.frame
                        ?? SettingsTheme.ink2.opacity(0.3)
                )
                .opacity(drawsChrome ? 1 : 0)
        )
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Whether a top or bottom strip runs the corner: the strip
    /// the engine measures first keeps it — the Space Bar's, whose
    /// edge `barEdges` lists first (`ShelfGeometry.strips`, #1731).
    var rowsRunFullWidth: Bool {
        settings.barEdges(
            space: spaceSpecIfShown != nil ? .always : nil,
            app: showsAppBar && appBarLook != nil ? .always : nil
        ).first?.edge.isHorizontal ?? false
    }

    private var columnsOuter: some View {
        HStack(spacing: 3) {
            columnBars(.left)
            VStack(spacing: 3) {
                rowBars(.top)
                well
                rowBars(.bottom)
            }
            columnBars(.right)
        }
    }

    private var rowsOuter: some View {
        VStack(spacing: 3) {
            rowBars(.top)
            HStack(spacing: 3) {
                columnBars(.left)
                well
                columnBars(.right)
            }
            rowBars(.bottom)
        }
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(
                palette?.ghostFill
                    ?? SettingsTheme.ink2.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(
                        palette?.frame
                            ?? SettingsTheme.ink2.opacity(0.3)
                    )
            )
            .opacity(drawsChrome ? 1 : 0)
            .overlay { wellContent }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func rowBars(_ edge: AppBarEdge) -> some View {
        shelfStrip(on: edge, vertical: false)
    }

    @ViewBuilder
    private func columnBars(_ edge: AppBarEdge) -> some View {
        shelfStrip(on: edge, vertical: true)
    }

    /// The strip on `edge`: each bar that sits there in the
    /// segment Core's `ShelfArrangement` gives it — both on one
    /// strip while they share the edge, one each while they are
    /// split (#1731) — so the preview never places a bar the
    /// engine would not (#702, #1517).
    @ViewBuilder
    private func shelfStrip(
        on edge: AppBarEdge,
        vertical: Bool
    ) -> some View {
        let space =
            settings.spaceBarStyle.edge == edge
            ? spaceSpecIfShown : nil
        let app =
            showsAppBar && settings.appBarStyle.edge == edge
            ? appBarLook.map { appSpec($0, vertical: vertical) }
            : nil
        if space != nil || app != nil {
            ShelfStripPreview(
                shelf: settings.kiwishelf,
                space: space,
                app: app,
                edge: edge,
                vertical: vertical,
                scale: scale,
                pocket: pocketStands && settings.kiwishelf.pocketEdge == edge,
                pocketHex: settings.pocketStyle.color
            )
        }
    }

    private var spaceSpecIfShown: BarSpec? {
        settings.spaceBarStyle.visibility.showsUnprompted
            ? spaceSpec(settings.spaceBarLook) : nil
    }

}
