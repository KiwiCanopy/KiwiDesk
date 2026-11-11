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
    let pointer: DesktopsPointer

    @Environment(\.kiwiHubPaint) private var paint

    private var desktop: DesktopOverview.Desktop {
        state.overview.screens[screen].desktops[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesktopsGeometry.titleGap) {
            title
            // A column cut short by the cap keeps the selected line
            // clear of its fade.
            FadingColumn(
                selected: selectedLine.map(lineID),
                ids: desktop.spaces.indices.map(lineID)
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(desktop.spaces.indices, id: \.self) {
                        line($0).id(lineID($0))
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

    private func lineID(_ line: Int) -> DesktopsScrollID {
        .line(DesktopsPlace(screen: screen, desktop: index, line: line))
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
            onDrop: onDrop,
            pointer: pointer
        )
    }

    private var titleTarget: JumpHover {
        .desktop(screen: screen, index: index)
    }

    /// The title, a button to its Desktop (#3209): the grey hover
    /// ground under the pointer, and `.help` as a second cue.
    private var title: some View {
        let lifted = pointer.lifts(titleTarget, selected: false)
        return HStack(spacing: 4) {
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
        .kiwiHubRowInk(paint, selected: false, lifted: lifted)
        .background {
            if lifted {
                RoundedRectangle(cornerRadius: 6)
                    .fill(paint.fill(paint.rowHover))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { click() }
        .desktopsHover(titleTarget, pointer)
        .help(DesktopsText.switchTo(desktop.label))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(DesktopsText.switchTo(desktop.label))
        .accessibilityAction { click(count: 1, modifiers: []) }
    }

    /// The title is ↩ on the Desktop it names (#3209): it jumps
    /// there; during a carry it drops on the line the Desktop shows.
    private func click() {
        let event = NSApp.currentEvent
        click(
            count: event?.clickCount ?? 1,
            modifiers: event?.modifierFlags ?? []
        )
    }

    private func click(count: Int, modifiers: NSEvent.ModifierFlags) {
        let line = desktop.spaces.firstIndex(where: \.isShown) ?? 0
        onPlace(
            DesktopsPlace(screen: screen, desktop: index, line: line),
            count,
            modifiers,
            false
        )
    }
}
