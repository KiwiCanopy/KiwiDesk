import AppKit
import KiwiDeskCore
import SwiftUI

/// KiwiHub's Desktops side (#1229): one row per screen in physical
/// order, the screen's name as its header, its Desktop cards in a
/// row that scrolls sideways; past two rows the side scrolls down.
struct DesktopsSideView: View {
    let state: DesktopsState
    let icons: [pid_t: NSImage]
    /// The tallest the side stands before it scrolls.
    let maxHeight: CGFloat
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void
    /// The panel's VoiceOver action for ⌘,.
    let onSettings: () -> Void

    /// A screen row: its header and one card's height.
    static var rowHeight: CGFloat { 22 + DesktopCardView.height }

    /// The side's height for `rows` screen rows: every row whole,
    /// up to `cap`, past which it scrolls.
    static func height(rows: Int, cap: CGFloat) -> CGFloat {
        let count = CGFloat(rows)
        let full = count * rowHeight + max(count - 1, 0) * 8 + 16
        return min(full, cap)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.overview.screens.indices, id: \.self) {
                        row($0).id($0)
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(height: height)
            .accessibilityAction(
                named: Text(DesktopsText.editInSettings),
                onSettings
            )
            .onAppear { proxy.scrollTo(state.place?.screen) }
            .onChange(of: state.place?.screen) { _, screen in
                proxy.scrollTo(screen)
            }
        }
    }

    private var height: CGFloat {
        Self.height(rows: state.overview.screens.count, cap: maxHeight)
    }

    private func row(_ screen: Int) -> some View {
        let row = state.overview.screens[screen]
        let selected = state.place.flatMap {
            $0.screen == screen ? $0.desktop : nil
        }
        return VStack(alignment: .leading, spacing: 4) {
            header(row)
            ViewLine(selected: selected) {
                HStack(spacing: 10) {
                    ForEach(row.desktops.indices, id: \.self) { index in
                        DesktopCardView(
                            state: state,
                            screen: screen,
                            index: index,
                            icons: icons,
                            onPlace: onPlace,
                            onWindow: onWindow,
                            onMore: onMore,
                            onDrop: onDrop
                        )
                        .id(index)
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
        .padding(.horizontal, KeyPanelStyle.selectionInset + 10)
    }

    /// "main", "here" or both, the row header's one caption.
    private func caption(_ row: DesktopOverview.Screen) -> String? {
        let words =
            (row.isMain ? [DesktopsText.main] : [])
            + (row.isHere ? [DesktopsText.here] : [])
        return words.isEmpty ? nil : words.joined(separator: " · ")
    }
}
