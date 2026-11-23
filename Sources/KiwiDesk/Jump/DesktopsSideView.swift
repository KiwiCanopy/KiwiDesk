import AppKit
import KiwiDeskCore
import SwiftUI

/// KiwiHub's Desktops side (#1229, #3570 ruling 4): one column per
/// screen in physical left-to-right order, the screen's name as its
/// header, its Desktops stacked downward. The columns share the
/// panel's width down to a floor past which the row of screens
/// scrolls sideways, never wrapping; past the height cap each
/// column scrolls down.
struct DesktopsSideView: View {
    let state: DesktopsState
    let icons: [pid_t: NSImage]
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void
    /// The panel's VoiceOver action for ⌘,.
    let onSettings: () -> Void
    /// The pointer's lift over a title, a line or an icon (#3209).
    let pointer: DesktopsPointer

    private var geometry: DesktopsGeometry { state.geometry }

    var body: some View {
        ViewLine(
            selected: state.place.map { DesktopsScrollID.screen($0.screen) },
            inset: DesktopsGeometry.rowInset
        ) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(state.overview.screens.indices, id: \.self) {
                    screen in
                    if screen > 0 {
                        PanelDivider(
                            axis: .vertical,
                            length: geometry.height
                                - 2 * DesktopsGeometry.sidePadding
                        )
                    }
                    column(screen).id(DesktopsScrollID.screen(screen))
                }
            }
            .padding(.vertical, DesktopsGeometry.sidePadding)
        }
        .frame(height: geometry.height)
        .desktopTitleHints()
        .accessibilityAction(
            named: Text(DesktopsText.editInSettings),
            onSettings
        )
    }

    private func column(_ screen: Int) -> some View {
        let row = state.overview.screens[screen]
        return VStack(alignment: .leading, spacing: DesktopsGeometry.headerGap)
        {
            header(row)
            // The selected line stays clear of the column's fade.
            FadingColumn(
                selected: selected(in: screen),
                ids: ids(of: screen)
            ) {
                VStack(
                    alignment: .leading,
                    spacing: DesktopsGeometry.desktopGap
                ) {
                    ForEach(row.desktops.indices, id: \.self) { index in
                        card(screen, index)
                            .id(DesktopsScrollID.desktop(screen, index))
                    }
                }
            }
            .frame(height: geometry.body, alignment: .top)
        }
        .frame(width: geometry.columns[screen], alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.title(row))
    }

    private func card(_ screen: Int, _ index: Int) -> some View {
        DesktopCardView(
            state: state,
            screen: screen,
            index: index,
            geometry: geometry,
            width: geometry.columns[screen],
            icons: icons,
            onPlace: onPlace,
            onWindow: onWindow,
            onMore: onMore,
            onDrop: onDrop,
            pointer: pointer
        )
    }

    /// The selected line's scroll id, where it is in this column.
    private func selected(in screen: Int) -> DesktopsScrollID? {
        guard let place = state.place, place.screen == screen else {
            return nil
        }
        return .line(place)
    }

    /// A column's scroll ids top to bottom: each Desktop's title,
    /// then its lines, so a reveal upward shows the title too.
    private func ids(of screen: Int) -> [DesktopsScrollID] {
        let desktops = state.overview.screens[screen].desktops
        return desktops.indices.flatMap { desktop -> [DesktopsScrollID] in
            [.desktop(screen, desktop)]
                + desktops[desktop].spaces.indices.map {
                    .line(
                        DesktopsPlace(
                            screen: screen,
                            desktop: desktop,
                            line: $0
                        )
                    )
                }
        }
    }

    /// The screen's name, its position added where a twin shares it.
    static func title(_ row: DesktopOverview.Screen) -> String {
        ScreenLabel.named(row.name, at: row.position)  // #3496
    }

    /// The column's header: the screen's name, and "main" on the
    /// screen with the menu bar. No "here": the starting selection
    /// says where KiwiHub opened (#3572 ruling 4).
    private func header(_ row: DesktopOverview.Screen) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "display")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(Self.title(row))
                .font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if row.isMain {
                Text(DesktopsText.main)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(height: DesktopsGeometry.headerHeight)
        .padding(.horizontal, DesktopsGeometry.columnInset + 4)
    }
}

/// The Desktops side's scroll ids, one space for its nested
/// scrolls: a reveal resolves a bare index in whichever scroll
/// holds it, and nudged another (#3164).
enum DesktopsScrollID: Hashable {
    case screen(Int)
    case desktop(Int, Int)
    case line(DesktopsPlace)
}
