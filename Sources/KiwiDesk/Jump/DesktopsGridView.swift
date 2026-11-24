import AppKit
import KiwiDeskCore
import SwiftUI

/// KiwiHub's Desktops side with shared Desktops on two or more
/// screens (#3602): one row per Desktop, its header on the left,
/// the screens as columns in physical order under their pinned
/// headers. One vertical scroll moves every row; past the panel's
/// width the screens scroll sideways under the frozen header column.
struct DesktopsGridView: View {
    let state: DesktopsState
    let icons: [pid_t: NSImage]
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void
    let pointer: DesktopsPointer

    private var geometry: DesktopsGeometry { state.geometry }
    private var lead: CGFloat { geometry.grid?.lead ?? 0 }
    private var rows: Range<Int> { state.overview.rows.indices }

    /// The grid's whole width: the header column, its gap, the
    /// columns and the hairlines between them.
    private var width: CGFloat {
        let columns = geometry.columns
        return lead + columns.reduce(0, +)
            + CGFloat(max(columns.count - 1, 0)) * DesktopsGeometry.divider
    }

    var body: some View {
        ViewLine(
            selected: state.place.map { DesktopsScrollID.screen($0.screen) },
            inset: DesktopsGeometry.rowInset,
            pinned: DesktopsGeometry.rowInset + lead
        ) {
            VStack(alignment: .leading, spacing: DesktopsGeometry.headerGap) {
                DesktopsGridHeader(state: state)
                // The selected line stays clear of the rows' fade.
                FadingColumn(selected: selected, ids: ids) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(rows, id: \.self) { index in
                            if index > 0 { PanelDivider() }
                            row(index).id(DesktopsScrollID.row(index))
                        }
                    }
                }
                .frame(width: width, height: geometry.body, alignment: .top)
            }
            .padding(.vertical, DesktopsGeometry.sidePadding)
        }
    }

    private func row(_ index: Int) -> some View {
        DesktopRowView(
            state: state,
            index: index,
            icons: icons,
            onPlace: onPlace,
            onWindow: onWindow,
            onMore: onMore,
            onDrop: onDrop,
            pointer: pointer
        )
    }

    private var selected: DesktopsScrollID? {
        state.place.map { .line($0) }
    }

    /// The scroll ids top to bottom in the selected screen's column:
    /// each row, then its lines there, so a reveal upward shows the
    /// row's top too.
    private var ids: [DesktopsScrollID] {
        guard let screen = state.place?.screen else { return [] }
        let desktops = state.overview.screens[screen].desktops
        return rows.flatMap { row -> [DesktopsScrollID] in
            guard desktops.indices.contains(row) else { return [] }
            return [.row(row)]
                + desktops[row].spaces.indices.map {
                    .line(
                        DesktopsPlace(screen: screen, desktop: row, line: $0)
                    )
                }
        }
    }
}

/// The grid's pinned header row: the screens' names over their
/// columns, nothing over the header column.
private struct DesktopsGridHeader: View {
    let state: DesktopsState

    @Environment(\.viewLineScrolled) private var scrolled

    private var lead: CGFloat { state.geometry.grid?.lead ?? 0 }

    var body: some View {
        let geometry = state.geometry
        HStack(spacing: 0) {
            Color.clear.frame(width: lead)
            HStack(spacing: 0) {
                ForEach(state.overview.screens.indices, id: \.self) {
                    screen in
                    if screen > 0 {
                        PanelDivider(
                            axis: .vertical,
                            length: DesktopsGeometry.headerHeight
                        )
                    }
                    DesktopsSideView.header(state.overview.screens[screen])
                        .frame(
                            width: geometry.columns[screen],
                            alignment: .leading
                        )
                        .background(alignment: .trailing) {
                            // The reveal's target reaches back over
                            // the frozen span, so a screen scrolled
                            // to lands clear of it.
                            Color.clear
                                .frame(
                                    width: geometry.columns[screen]
                                        + DesktopsGeometry.rowInset + lead
                                )
                                .id(DesktopsScrollID.screen(screen))
                        }
                }
            }
            .frozenCut(scrolled)
        }
    }
}
