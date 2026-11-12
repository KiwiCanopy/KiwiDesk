import AppKit
import KiwiDeskCore
import SwiftUI

/// KiwiHub's Desktops side (#1229): one row per screen in physical
/// order, the screen's name as its header, its Desktops as columns
/// split by dividers, sharing the row's width down to a floor past
/// which the row scrolls sideways; past two rows the side scrolls
/// down (#3164).
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
        FadingColumn(
            selected: state.place.map { DesktopsScrollID.screen($0.screen) },
            ids: state.overview.screens.indices.map(DesktopsScrollID.screen),
            inset: DesktopsGeometry.sidePadding
        ) {
            VStack(alignment: .leading, spacing: DesktopsGeometry.rowGap) {
                ForEach(state.overview.screens.indices, id: \.self) {
                    row($0, geometry).id(DesktopsScrollID.screen($0))
                }
            }
        }
        .frame(height: geometry.height)
        .accessibilityAction(
            named: Text(DesktopsText.editInSettings),
            onSettings
        )
    }

    private func row(
        _ screen: Int,
        _ geometry: DesktopsGeometry
    ) -> some View {
        let row = state.overview.screens[screen]
        let selected = state.place.flatMap {
            $0.screen == screen
                ? DesktopsScrollID.desktop($0.screen, $0.desktop) : nil
        }
        return VStack(alignment: .leading, spacing: DesktopsGeometry.headerGap)
        {
            header(row)
            ViewLine(selected: selected, inset: DesktopsGeometry.rowInset) {
                HStack(spacing: 0) {
                    ForEach(row.desktops.indices, id: \.self) { index in
                        if index > 0 {
                            PanelDivider(
                                axis: .vertical,
                                length: geometry.column(screen)
                            )
                        }
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
                        .id(DesktopsScrollID.desktop(screen, index))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.name)
    }

    private func header(_ row: DesktopOverview.Screen) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "display")
                .font(.caption2)
                .accessibilityHidden(true)
            Text(row.name)
                .font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if let caption = caption(row) {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(height: DesktopsGeometry.headerHeight)
        .padding(.horizontal, DesktopsGeometry.rowInset)
    }

    /// "main", "here" or both, the row header's one caption.
    private func caption(_ row: DesktopOverview.Screen) -> String? {
        let words =
            (row.isMain ? [DesktopsText.main] : [])
            + (row.isHere ? [DesktopsText.here] : [])
        return words.isEmpty ? nil : words.joined(separator: " · ")
    }
}

/// The Desktops side's scroll ids, one space for its three nested
/// scrolls: a reveal resolves a bare index in whichever scroll
/// holds it, and nudged another (#3164).
enum DesktopsScrollID: Hashable {
    case screen(Int)
    case desktop(Int, Int)
    case line(DesktopsPlace)
}
