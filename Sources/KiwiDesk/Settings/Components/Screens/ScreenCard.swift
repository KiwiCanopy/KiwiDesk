import Foundation
import KiwiDeskCore
import SwiftUI

/// Screen card in the Screens arrangement preview (#678, #758): the
/// plate, outline, main glow and rise of one physical screen, laid
/// with one `ScreenAreaPane` per area and, on a split screen, the
/// dividers between them (#3517 rulings 24, 25, 27).
struct ScreenCard: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    /// Row expansion from census.
    let rows: ScreensFamilyRows
    /// Scaled dimensions from arrangement.
    let size: CGSize
    @Binding var selection: ScreenSelection?
    /// The area giving way in an open Adjust… popover.
    let givingWay: Set<ScreenSelection>
    /// The pane a menu's Split or Merge hands focus to.
    let paneFocus: ScreenSelection?
    let act: (ScreenAreaAction) -> Void
    @State private var hovering = false
    @State private var drag: AreaDividerDrag?
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let split = drag?.split ?? model.areaSplit(of: display)
        ZStack(alignment: .topLeading) {
            ForEach(panes(split), id: \.id) { pane in
                paneView(pane, split: split)
            }
            if let stored = model.areaSplit(of: display) {
                dividers(stored)
                capsules(split)
            }
        }
        .frame(
            width: size.width,
            height: size.height,
            alignment: .topLeading
        )
        .background(plate)
        .overlay(border)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        // Main screen accent glow (#758, ui-designer 2026-08-09).
        .compositingGroup()
        .shadow(
            color: isMain
                ? SettingsTheme.accent.opacity(0.55)
                : .clear,
            radius: isMain ? 6 : 0
        )
        .hoverRise(risen, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
        // Over the next card, which would cover the shadow.
        .zIndex(risen ? 1 : 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.screenLabel(display))
        .accessibilityValue(splitValue)
    }

    /// Checked by ID rather than fingerprint for duplicate screens
    /// (2026-08-04).
    private var isMain: Bool {
        model.mainDisplay?.id == display.id
    }

    /// A card rises under the pointer, selected or not: its click
    /// deselects (#3042). A drag in flight answers with its wash.
    private var risen: Bool { hovering && isEnabled && !targeted }

    /// The panes a dragged Space is over: each owns its own drop,
    /// and one's enter may come before another's exit.
    @State private var targetedPanes: Set<Int> = []

    private var targeted: Bool { !targetedPanes.isEmpty }

    private struct Pane {
        let id: Int
        let rect: CGRect
        let key: String
        let leads: Bool
    }

    private func panes(_ split: ScreenSplit?) -> [Pane] {
        ScreenArrangement.unitAreas(of: split).enumerated().map {
            index,
            unit in
            Pane(
                id: unit.id,
                rect: ScreenArrangement.paneRect(unit.rect, in: size),
                key: ScreenAreaKey(
                    fingerprint: display.fingerprint,
                    areaID: split == nil ? 0 : unit.id
                ).description,
                leads: index == 0
            )
        }
    }

    private func paneView(_ pane: Pane, split: ScreenSplit?) -> some View {
        ScreenAreaPane(
            model: model,
            display: display,
            rows: rows,
            area: split == nil ? nil : pane.id,
            key: pane.key,
            leads: pane.leads,
            size: pane.rect.size,
            corners: corners(pane.rect),
            givesWay: givingWay.contains(
                ScreenSelection(display: display.id, area: pane.id)
            ),
            selection: $selection,
            act: act,
            focusRequest: paneFocus,
            onTargeted: { inside in
                if inside {
                    targetedPanes.insert(pane.id)
                } else {
                    targetedPanes.remove(pane.id)
                }
            }
        )
        .offset(x: pane.rect.minX, y: pane.rect.minY)
    }

    /// Round only the corners that are the card's own, so a seam
    /// meets its neighbour square.
    private func corners(_ rect: CGRect) -> RectangleCornerRadii {
        let left = rect.minX < 0.5
        let top = rect.minY < 0.5
        let right = rect.maxX > size.width - 0.5
        let bottom = rect.maxY > size.height - 0.5
        return RectangleCornerRadii(
            topLeading: left && top ? 6 : 0,
            bottomLeading: left && bottom ? 6 : 0,
            bottomTrailing: right && bottom ? 6 : 0,
            topTrailing: right && top ? 6 : 0
        )
    }

    /// Card points per screen point along each axis.
    private func scale(_ split: ScreenSplit) -> CGSize {
        let width = CGFloat(max(split.extent.width, 1))
        let height = CGFloat(max(split.extent.height, 1))
        return CGSize(width: size.width / width, height: size.height / height)
    }

    /// Each divider is handed the STORED cut, which its drag starts
    /// from, and drawn where the drag in flight has it.
    @ViewBuilder private func dividers(_ stored: ScreenSplit) -> some View {
        let width = stored.extent.width
        let height = stored.extent.height
        let cuts =
            ScreenAreaCuts.cuts(of: stored.areas, width: width, height: height)
            ?? []
        let drawn =
            drag.flatMap {
                ScreenAreaCuts.cuts(
                    of: $0.split.areas,
                    width: width,
                    height: height
                )
            } ?? cuts
        let factor = scale(stored)
        ForEach(Array(cuts.enumerated()), id: \.offset) { index, cut in
            let side = cut.axis == .sideBySide
            let position =
                drawn.indices.contains(index)
                ? drawn[index].position : cut.position
            let at = CGFloat(position) * (side ? factor.width : factor.height)
            // A nested cut spans only its own box (#3541).
            let across = side ? factor.height : factor.width
            let from = CGFloat(cut.start) * across
            let span = CGFloat(cut.end - cut.start) * across
            let band = ScreenAreaDivider.hitBand
            ScreenAreaDivider(
                model: model,
                display: display,
                split: stored,
                index: index,
                cut: cut,
                scale: side ? factor.width : factor.height,
                drag: $drag
            )
            .frame(
                width: side ? band : span,
                height: side ? span : band
            )
            .offset(
                x: side ? at - band / 2 : from,
                y: side ? from : at - band / 2
            )
        }
    }

    /// While a divider moves, each area beside it shows its length,
    /// the one a snap made a screen fraction naming it (ruling 25).
    @ViewBuilder private func capsules(_ split: ScreenSplit?) -> some View {
        if let drag, let split,
            let cut = ScreenAreaCuts.cuts(
                of: split.areas,
                width: split.extent.width,
                height: split.extent.height
            )?[safe: drag.cut]
        {
            let side = cut.axis == .sideBySide
            ForEach(
                (cut.leading.prefix(1) + cut.trailing.prefix(1)),
                id: \.self
            ) { id in
                if let unit = ScreenArrangement.unitAreas(of: split)
                    .first(where: { $0.id == id })?.rect,
                    let area = split.areas.first(where: { $0.id == id })
                {
                    let rect = ScreenArrangement.paneRect(unit, in: size)
                    AreaSizeCapsule(
                        length: side ? area.w : area.h,
                        snap: drag.snap,
                        total: side
                            ? split.extent.width
                            : split.extent.height
                    )
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: 6)
            // The soft green, not the white card surface (owner,
            // 2026-08-09 — the prototype's own colouring).
            .fill(SettingsTheme.sunken)
            .shadow(radius: 0.5, y: 0.5)
    }

    /// A whole screen's hover edge is the card's; a split card's
    /// panes take it instead, so the outline stays at rest.
    private var border: some View {
        let edge = risen && model.areaSplit(of: display) == nil
        return RoundedRectangle(cornerRadius: 6)
            .strokeBorder(
                edge
                    ? SettingsTheme.hoverEdge
                    : SettingsTheme.ink3.opacity(0.5),
                lineWidth: edge
                    ? SettingsTheme.hoverEdgeStroke
                    : SettingsTheme.screenCardStroke
            )
    }

    /// The card's value: how it is split, the panes saying the rest.
    private var splitValue: String {
        guard let split = model.areaSplit(of: display) else { return "" }
        let count = split.areas.count
        switch split.axis {
        case .stacked?:
            return L(
                "monitor_card.split.stacked.ax",
                "Areas: %1$d, top to bottom",
                count
            )
        case .sideBySide?:
            return L(
                "monitor_card.split.side_by_side.ax",
                "Areas: %1$d, side by side",
                count
            )
        case nil:
            return L("monitor_card.split.nested.ax", "Areas: %1$d", count)
        }
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
