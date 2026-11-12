import AppKit
import KiwiDeskCore
import SwiftUI
import UniformTypeIdentifiers

/// One Space's line in a Desktop's column (#1229): the shown-Space
/// capsule, the layout symbol, the Space's name, then as many app
/// icons as its width holds with "+n" counts off each edge (#3164).
/// Colour carries nothing alone: the capsule, an underline under
/// the last-focused window, a dashed outline on a picked one and a
/// solid stroke on a carry's target.
struct DesktopLineView: View {
    let state: DesktopsState
    let place: DesktopsPlace
    let geometry: DesktopsGeometry
    let icons: [pid_t: NSImage]
    let onPlace: (DesktopsPlace, Int, NSEvent.ModifierFlags, Bool) -> Void
    let onWindow: (WindowID, DesktopsPlace, Int, NSEvent.ModifierFlags) -> Void
    let onMore: (DesktopsPlace, Bool) -> Void
    let onDrop: ([WindowID], DesktopsPlace) -> Void
    let pointer: DesktopsPointer

    @Environment(\.kiwiHubPaint) private var paint
    @Environment(\.desktopsSwell) private var swell
    @State private var dropTargeted = false

    private var line: DesktopOverview.SpaceLine? { state.line(place) }
    private var isSelected: Bool { state.place == place }
    /// The selected place while windows ride along: a target.
    private var isTarget: Bool {
        (isSelected && state.isCarrying && !state.isInside)
            || dropTargeted
    }
    /// The pointer lifts the line, grey, never the selected one.
    private var isLifted: Bool {
        pointer.lifts(
            .place(place),
            selected: isSelected && !state.isInside,
            clickable: state.target(place) != nil
        )
    }

    var body: some View {
        HStack(spacing: 4) {
            label
            Spacer(minLength: 2)
            // The icons keep their slots; a long Space name truncates.
            slots.layoutPriority(1)
        }
        .padding(.horizontal, DesktopsGeometry.linePadding)
        .frame(height: geometry.line)
        .background(ground)
        .opacity(state.hasMatch(place) ? 1 : 0.45)
        .contentShape(Rectangle())
        .onTapGesture { click() }
        .desktopsHover(.place(place), pointer)
        .onDrop(of: [.plainText], isTargeted: $dropTargeted) { items in
            DesktopsDrag.receive(items) { onDrop($0, place) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(line.map(spoken) ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func spoken(_ line: DesktopOverview.SpaceLine) -> String {
        guard let desktop = state.desktop(place) else { return "" }
        return DesktopsText.spoken(line, on: desktop)
    }

    /// Whether the line wears the selection's whole fill and ink: the
    /// selected line, never a drop target's tint (#3264).
    private var wearsFill: Bool {
        !isTarget && isSelected && !state.isInside
    }

    @ViewBuilder private var ground: some View {
        let shape = RoundedRectangle(cornerRadius: 6)
        if isTarget {
            shape.fill(
                paint.fill(
                    paint.selection.opacity(0.35)
                )
            )
            .overlay(shape.strokeBorder(paint.selection, lineWidth: 2))
        } else if wearsFill {
            shape.fill(paint.fill(paint.selection))
        } else if isLifted {
            shape.fill(paint.fill(paint.rowHover))
        }
    }

    private var ink: AnyShapeStyle {
        if wearsFill {
            return AnyShapeStyle(paint.selectionInk)
        }
        if isLifted, !isTarget, let hoverInk = paint.hoverInk {
            return AnyShapeStyle(hoverInk)
        }
        return AnyShapeStyle(.primary)
    }

    @ViewBuilder private var label: some View {
        if let line {
            HStack(spacing: 4) {
                if let mode = line.mode {
                    Image(systemName: mode.symbol)
                        .font(.caption)
                        .accessibilityHidden(true)
                }
                Text(line.space.map(\.raw) ?? DesktopsText.unfiled)
                    .font(.callout.weight(line.isShown ? .bold : .regular))
                    .lineLimit(1)
                    .padding(.horizontal, line.isShown ? 5 : 0)
                    .background {
                        if line.isShown {
                            Capsule().strokeBorder(lineWidth: 1.2)
                        }
                    }
                if let marker = line.marker {
                    // The Space Bar's marker symbols (#1507, #1790).
                    Image(
                        systemName: marker == .held
                            ? "display.2" : "hourglass"
                    )
                    .font(.caption2)
                    .accessibilityHidden(true)
                }
            }
            .foregroundStyle(ink)
            .desktopsSwell(swell == .place(place), anchor: .leading)
        }
    }

    @ViewBuilder private var slots: some View {
        let drawn = state.ordered(place)
        if drawn.isEmpty {
            Text(DesktopsText.empty)
                .font(.caption)
                .foregroundStyle(ink)
                .opacity(0.7)
        } else {
            let first = state.offset(place)
            let shown = Array(
                drawn.dropFirst(first).prefix(state.slots(place))
            )
            let hidden = state.hidden(place)
            HStack(spacing: DesktopsGeometry.iconGap) {
                more(hidden.before, forward: false)
                ForEach(shown, id: \.id) { window in
                    DesktopIconView(
                        window: window,
                        size: geometry.icon,
                        image: icons[window.pid],
                        isSelected: state.window == window.id,
                        isPicked: state.carried.contains(window.id),
                        isLast: line?.lastFocused == window.id,
                        isMatch: state.matches(window),
                        onFill: wearsFill,
                        dragged: dragged(window.id),
                        pointer: pointer,
                        onClick: { count, modifiers in
                            onWindow(window.id, place, count, modifiers)
                        }
                    )
                    .desktopsSwell(
                        swell == .window(window.id),
                        anchor: .center
                    )
                }
                more(hidden.after, forward: true)
            }
        }
    }

    /// A picked icon drags the whole set, an unpicked one itself.
    private func dragged(_ id: WindowID) -> [WindowID] {
        state.carried.contains(id) ? state.carried : [id]
    }

    @ViewBuilder private func more(_ count: Int, forward: Bool) -> some View {
        if count > 0 {
            Button {
                onMore(place, forward)
            } label: {
                Text(verbatim: "+\(count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.plain)
        }
    }

    private func click() {
        let click = DesktopsClick.of(NSApp.currentEvent)
        onPlace(place, click.count, click.modifiers, true)
    }
}
