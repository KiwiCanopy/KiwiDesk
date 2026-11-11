import AppKit
import KiwiDeskCore
import SwiftUI

/// One Desktop's column on the Desktops side (#1229): its title
/// line — "Desktop N", ✓ while its screen shows it, the bound
/// profile on the right — and one line per Space, on the panel's
/// own ground (#3164). A row's columns share one width.
struct DesktopCardView: View {
    let state: DesktopsState
    let screen: Int
    let index: Int
    let geometry: DesktopsGeometry
    /// The column's width (`DesktopsGeometry.columns`).
    let width: CGFloat
    let icons: [pid_t: NSImage]
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void

    private var desktop: DesktopOverview.Desktop {
        state.overview.screens[screen].desktops[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesktopsGeometry.titleGap) {
            title
            // A column cut short by the cap keeps the selected line
            // clear of its fade.
            FadingColumn(selected: selectedLine) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(desktop.spaces.indices, id: \.self) {
                        line($0).id($0)
                    }
                }
            }
            .frame(height: geometry.lines[screen], alignment: .top)
        }
        .padding(.horizontal, DesktopsGeometry.columnInset)
        .frame(width: width, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DesktopsText.desktop(desktop.label))
    }

    /// The selected line, where the selection is in this column.
    private var selectedLine: Int? {
        guard let place = state.place, place.screen == screen,
            place.desktop == index
        else { return nil }
        return place.line
    }

    private func line(_ line: Int) -> some View {
        DesktopLineView(
            state: state,
            place: DesktopsPlace(screen: screen, desktop: index, line: line),
            geometry: geometry,
            icons: icons,
            onPlace: onPlace,
            onWindow: onWindow,
            onMore: onMore,
            onDrop: onDrop
        )
    }

    private var title: some View {
        HStack(spacing: 4) {
            Text(DesktopsText.desktop(desktop.label))
                .font(.callout.weight(.semibold))
            if desktop.isShown {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .accessibilityLabel(DesktopsText.shown)
            }
            Spacer(minLength: 4)
            if let profile = desktop.profile {
                Text(profile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .truncationMode(.tail)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, 4)
        .frame(height: DesktopsGeometry.titleHeight)
        .contentShape(Rectangle())
        .onTapGesture { click() }
    }

    /// The title selects the line the Desktop shows; a double click
    /// jumps to the Desktop.
    private func click() {
        let line = desktop.spaces.firstIndex(where: \.isShown) ?? 0
        let event = NSApp.currentEvent
        onPlace(
            DesktopsPlace(screen: screen, desktop: index, line: line),
            event?.clickCount ?? 1,
            event?.modifierFlags ?? [],
            false
        )
    }
}
