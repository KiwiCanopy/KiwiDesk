import AppKit
import KiwiDeskCore
import SwiftUI

/// One Desktop's card on the Desktops side (#1229): its title line —
/// "Desktop N", ✓ while its screen shows it, the bound profile on
/// the right — and one line per Space. Every card is one size.
struct DesktopCardView: View {
    let state: DesktopsState
    let screen: Int
    let index: Int
    let icons: [pid_t: NSImage]
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void

    @Environment(\.kiwiHubPaint) private var paint

    static var width: CGFloat { 224 }
    static var height: CGFloat { 170 }
    static var titleHeight: CGFloat { 22 }

    private var desktop: DesktopOverview.Desktop {
        state.overview.screens[screen].desktops[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(desktop.spaces.indices, id: \.self) {
                            line($0).id($0)
                        }
                    }
                }
                // A card past four Spaces keeps the selected one in
                // view.
                .onAppear { proxy.scrollTo(selectedLine) }
                .onChange(of: selectedLine) { _, line in
                    proxy.scrollTo(line)
                }
            }
        }
        .padding(6)
        .frame(width: Self.width, height: Self.height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(paint.fill(paint.rowHover))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DesktopsText.desktop(desktop.label))
    }

    /// The selected line, where the selection is on this card.
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
        .frame(height: Self.titleHeight)
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
