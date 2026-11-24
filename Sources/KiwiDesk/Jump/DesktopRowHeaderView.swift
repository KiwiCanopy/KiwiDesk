import AppKit
import KiwiDeskCore
import SwiftUI

/// A shared Desktop's row header (#3602): its title and, while the
/// screens show it, the ✓; the bound profile below. A button to its
/// Desktop like a card's title (#3209), landing in the column of
/// the screen or area KiwiHub opened over; no keyboard stop.
struct DesktopRowHeaderView: View {
    let state: DesktopsState
    let index: Int
    let height: CGFloat
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let pointer: DesktopsPointer

    private var geometry: DesktopsGeometry { state.geometry }
    /// The column the header acts in: the screen KiwiHub opened on.
    private var here: Int {
        state.overview.screens.firstIndex(where: \.isHere) ?? 0
    }
    /// The header's facts: the row's, never one column's.
    private var row: DesktopOverview.Row { state.overview.rows[index] }

    /// The hover its row rings for (`DesktopRowView`).
    static func target(
        _ state: DesktopsState,
        _ index: Int
    ) -> JumpHover {
        let here = state.overview.screens.firstIndex(where: \.isHere) ?? 0
        return .desktop(screen: here, index: index)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(DesktopsText.desktop(row.label))
                    .font(.callout.weight(.semibold))
                if row.isShown {
                    // The card title's "in use" mark: own ink at full
                    // strength, never the accent (#3210, #3484).
                    Image(systemName: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .accessibilityLabel(DesktopsText.shown)
                }
            }
            .frame(height: DesktopsGeometry.titleHeight)
            if let profile = row.profile {
                Text(profile)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .truncationMode(.tail)
                    .frame(height: DesktopsGeometry.profileHeight)
                    .help(profile)
            }
        }
        .lineLimit(1)
        .padding(.leading, DesktopsGeometry.headerLeading)
        .padding(.trailing, DesktopsGeometry.headerTrailing)
        .padding(
            .top,
            DesktopsGeometry.rowPadding
                + DesktopsGeometry.titleTop(line: geometry.line)
        )
        .frame(
            width: geometry.grid?.gutter ?? 0,
            height: height,
            alignment: .topLeading
        )
        .contentShape(Rectangle())
        .onTapGesture { click() }
        .desktopsHover(Self.target(state, index), pointer)
        .help(DesktopsText.switchTo(row.label))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(DesktopsText.switchTo(row.label))
        .accessibilityAction { click(count: 1, modifiers: []) }
    }

    private func click() {
        let click = DesktopsClick.of(NSApp.currentEvent)
        self.click(count: click.count, modifiers: click.modifiers)
    }

    private func click(count: Int, modifiers: NSEvent.ModifierFlags) {
        onPlace(
            DesktopsPlace(
                screen: here,
                desktop: index,
                line: state.overview.screens[here].desktops[index]
                    .landingLine
            ),
            count,
            modifiers,
            false
        )
    }
}
