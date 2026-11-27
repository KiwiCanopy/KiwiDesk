import AppKit
import KiwiDeskCore
import SwiftUI

/// The Windows side's list: the ranked rows under their section
/// headers, capped at `rowCap` rows, its cut edges fading.
extension JumpPanelView {
    @ViewBuilder var results: some View {
        if model.list.drawnRows == 0 {
            Text(model.emptyText)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: JumpRowView.height)
                .padding(.vertical, Self.listPadding)
        } else {
            // Its edges fade where rows run past them, the side's one
            // cue that it scrolls (#3249).
            FadingColumn(
                selected: model.list.selection,
                ids: Array(0..<model.list.rowCount),
                inset: Self.listPadding
            ) {
                VStack(spacing: 0) {
                    // Greyed and never a row the keys reach.
                    if let yours = model.list.yours {
                        JumpYoursLine(
                            entry: yours,
                            icon: model.icons[yours.pid]
                        )
                    }
                    rows
                }
                .padding(.horizontal, KeyPanelStyle.selectionInset)
            }
            .frame(height: listHeight)
        }
    }

    var rows: some View {
        let list = model.list
        let here = JumpRowText.here(of: list.snapshot)
        let acted = JumpHover.actedRow(
            hover: model.hover,
            selection: list.selection
        )
        // Eager: a lazy stack left a row below the fold unbuilt, so
        // the selection's scroll found no row to reach.
        return VStack(spacing: 0) {
            ForEach(0..<list.rowCount, id: \.self) { index in
                // One scroll target with its header, so a selection
                // landing on a section's first row brings the header
                // into view with it.
                VStack(spacing: 0) {
                    if let section = list.section(at: index) {
                        sectionHeader(section)
                    }
                    if let app = list.appRow(index) {
                        appRow(index, app)
                    } else {
                        row(
                            index,
                            list.results[index],
                            here: here,
                            acted: acted
                        )
                    }
                }
                .id(index)
            }
        }
    }

    func row(
        _ index: Int,
        _ match: JumpSearch.Match,
        here: JumpRowText.Place?,
        acted: Int?
    ) -> some View {
        let list = model.list
        let entry = match.entry
        // A trade inside one Space, or with a window not here, has
        // no route to here to draw.
        let snapshot = list.snapshot
        let trades =
            entry.swapsHere && snapshot.swapsInHere
            && entry.space != snapshot.here
        return JumpRowView(
            match: match,
            icon: model.icons[match.entry.pid],
            isSelected: index == list.selection,
            isLifted: JumpHover.lifts(
                .row(index),
                hover: model.hover,
                selected: index == list.selection,
                clickable: true
            ),
            ownsShift: index == acted,
            ownsOption: index == acted,
            number: JumpList.number(ofRow: index),
            commandHeld: model.commandHeld,
            shiftHeld: model.shiftHeld,
            optionHeld: model.optionHeld,
            wayHere: entry.movesHere && here != nil ? here : nil,
            waySwap: trades ? here : nil,
            refusal: JumpRowRefusal(entry: entry),
            pulsing: model.refusedRow == index,
            revealed: model.revealedRow == index,
            onActivate: { pick in
                model.clickRow(index, pick: pick)
            },
            pickModifiers: { model.pickModifiers(NSEvent.modifierFlags) },
            onHover: {
                model.hoverRow(index, pointer: model.currentPointer())
            },
            onHoverEnd: { model.endHover(.row(index)) }
        )
    }

    /// An Applications row (#3704): its ⌘ number runs on from the
    /// windows', and ↩ or a click opens the app.
    func appRow(_ index: Int, _ app: JumpAppMatch) -> some View {
        let list = model.list
        return JumpAppRowView(
            match: app,
            icon: AppIconCache.shared.icon(forBundleID: app.app.bundleID),
            isSelected: index == list.selection,
            isLifted: JumpHover.lifts(
                .row(index),
                hover: model.hover,
                selected: index == list.selection,
                clickable: true
            ),
            number: JumpList.number(ofRow: index),
            commandHeld: model.commandHeld,
            refused: model.revealedRow == index,
            pulsing: model.refusedRow == index,
            onActivate: { pick in model.clickRow(index, pick: pick) },
            pickModifiers: { model.pickModifiers(NSEvent.modifierFlags) },
            onHover: {
                model.hoverRow(index, pointer: model.currentPointer())
            },
            onHoverEnd: { model.endHover(.row(index)) }
        )
    }

    func sectionHeader(_ section: JumpList.Section) -> some View {
        Text(JumpRowText.header(section))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, JumpRowView.padding)
            .padding(.bottom, 3)
            .frame(height: Self.headerHeight, alignment: .bottom)
    }

    /// The list's height: what its rows take, up to `rowCap` rows.
    var listHeight: CGFloat {
        Self.listHeight(
            rows: model.list.drawnRows,
            headers: model.list.sectionCount,
            rowCap: model.rowCap
        )
    }

    static func content(rows: Int, headers: Int) -> CGFloat {
        CGFloat(rows) * JumpRowView.height
            + CGFloat(headers) * headerHeight
    }

    static func listHeight(
        rows: Int,
        headers: Int,
        rowCap: Int
    ) -> CGFloat {
        let cap = CGFloat(rowCap) * JumpRowView.height
        return min(content(rows: rows, headers: headers), cap)
            + 2 * listPadding
    }
}
