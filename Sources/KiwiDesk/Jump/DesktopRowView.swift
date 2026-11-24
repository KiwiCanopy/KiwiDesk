import AppKit
import KiwiDeskCore
import SwiftUI

/// One shared Desktop's row in the grid (#3602): its header in the
/// frozen column, then one cell per screen, top-aligned, a hairline
/// between two screens. The header's hover rings the whole row
/// (#3484 as amended): the click reaches every screen.
struct DesktopRowView: View {
    let state: DesktopsState
    let index: Int
    let icons: [pid_t: NSImage]
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void
    let pointer: DesktopsPointer

    @Environment(\.kiwiHubPaint) private var paint
    /// The sideways scroll the header column stays put through.
    @Environment(\.viewLineScrolled) private var scrolled

    private var geometry: DesktopsGeometry { state.geometry }
    private var height: CGFloat { geometry.grid?.rows[index] ?? 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            DesktopRowHeaderView(
                state: state,
                index: index,
                height: height,
                onPlace: onPlace,
                pointer: pointer
            )
            .offset(x: scrolled)
            .zIndex(1)
            Color.clear.frame(width: DesktopsGeometry.gutterGap)
            cells.frozenCut(scrolled)
        }
        .frame(height: height, alignment: .top)
        .overlay { ring }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            DesktopsText.desktop(state.overview.rows[index].label)
        )
    }

    private var cells: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(state.overview.screens.indices, id: \.self) { screen in
                if screen > 0 {
                    PanelDivider(axis: .vertical, length: height)
                }
                cell(screen)
            }
        }
    }

    private func cell(_ screen: Int) -> some View {
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
            pointer: pointer,
            titled: false
        )
        .padding(.vertical, DesktopsGeometry.rowPadding)
        .frame(height: height, alignment: .top)
    }

    /// The row's hover: a thin selection ring round the header and
    /// every cell while the pointer is on the header, no ground; the
    /// fill stays the selection's alone (#1173).
    @ViewBuilder private var ring: some View {
        let target = DesktopRowHeaderView.target(state, index)
        if pointer.lifts(target, selected: false) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(paint.selection, lineWidth: 1.5)
                .padding(2)
                // Its leading edge stays with the frozen header.
                .padding(.leading, scrolled)
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Cuts what slides under the grid's frozen header column, for
    /// the eye and the pointer alike: `scrolled` points from the
    /// leading edge (#3602).
    func frozenCut(_ scrolled: CGFloat) -> some View {
        mask(alignment: .leading) {
            Rectangle().padding(.leading, scrolled)
        }
        .contentShape(LeadingCut(cut: scrolled))
    }
}

/// A rectangle less its first `cut` points.
private struct LeadingCut: Shape {
    let cut: CGFloat

    func path(in rect: CGRect) -> Path {
        let cut = min(max(cut, 0), rect.width)
        return Path(
            CGRect(
                x: rect.minX + cut,
                y: rect.minY,
                width: rect.width - cut,
                height: rect.height
            )
        )
    }
}
