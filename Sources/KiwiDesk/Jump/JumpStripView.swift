import AppKit
import KiwiDeskCore
import SwiftUI

/// The Windows side's app strip (#3135): All, the app you are in,
/// then the recent apps, under the field, shown off All or under a
/// query (#3168). It scrolls sideways with fades and follows the
/// selection on KiwiHub's `ViewLine` (#2901); a tile the query
/// leaves without a match dims in place, so the strip never
/// reflows.
struct JumpStripView: View {
    @ObservedObject var model: JumpModel

    static let spacing: CGFloat = 4
    static let verticalPadding: CGFloat = 6

    var body: some View {
        ViewLine(selected: model.list.tile) { tiles }
            .padding(.vertical, Self.verticalPadding)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(JumpStripText.stripName)
    }

    /// The run of tiles the line scrolls.
    var tiles: some View {
        let list = model.list
        return HStack(spacing: Self.spacing) {
            ForEach(0..<list.tileCount, id: \.self) { index in
                tile(index, in: list).id(index)
            }
        }
    }

    private func tile(_ index: Int, in list: JumpList) -> some View {
        let app = index == 0 ? nil : list.snapshot.apps[index - 1]
        let selected = index == list.tile
        let dimmed = !list.tileMatches(index)
        return JumpStripTile(
            name: app?.name ?? JumpStripText.allName,
            icon: app.flatMap { model.icons[$0.pid] },
            windows: app.map { list.windowCount(of: $0) } ?? 0,
            isSelected: selected,
            isLifted: JumpHover.lifts(
                .tile(index),
                hover: model.hover,
                selected: selected,
                clickable: !dimmed
            ),
            isDimmed: dimmed,
            onActivate: { model.clickTile(index) },
            onHover: {
                model.hoverTile(index, pointer: model.currentPointer())
            },
            onHoverEnd: { model.endHover(.tile(index)) }
        )
    }
}

/// One tile: the app's icon — All's grid symbol on a neutral plate
/// — and its name under it, one line, middle-truncated; a neutral
/// count capsule for two or more windows, never red. Rows fill,
/// tiles ring (#3210): the selected tile wears a 2 pt ring and no
/// fill, a lifted one the hover ground and its ink.
struct JumpStripTile: View {
    let name: String
    /// nil draws All's symbol.
    let icon: NSImage?
    let windows: Int
    let isSelected: Bool
    /// The pointer lifts this tile (#2365), never the selected one.
    let isLifted: Bool
    let isDimmed: Bool
    let onActivate: () -> Void
    let onHover: () -> Void
    let onHoverEnd: () -> Void
    @Environment(\.kiwiHubPaint) private var paint

    static let width: CGFloat = 92
    static let iconSize: CGFloat = 48

    var body: some View {
        Button(action: onActivate) {
            // Only the pointer's lift sits on the hover ground and
            // takes its measured ink; the selection is the ring.
            content.kiwiHubRowInk(
                paint,
                selected: false,
                lifted: isLifted
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(isDimmed)
        .onContinuousHover { phase in
            if case .active = phase { onHover() } else { onHoverEnd() }
        }
        .accessibilityLabel(JumpStripText.spoken(name, windows: windows))
        // A dim is not a sentence: a tile with no match says why.
        .accessibilityHint(isDimmed ? JumpStripText.noMatch : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var content: some View {
        VStack(spacing: 3) {
            mark.overlay(alignment: .topTrailing) { count }
            Text(name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(
                    isSelected
                        ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
                )
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .frame(width: Self.width)
        .background(ground)
        .opacity(isDimmed ? 0.35 : 1)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var mark: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: Self.iconSize, height: Self.iconSize)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary)
                )
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var count: some View {
        if windows > 1 {
            Text(verbatim: "\(windows)")
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(.quaternary))
                .offset(x: 10, y: -4)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var ground: some View {
        let shape = RoundedRectangle(
            cornerRadius: KeyPanelStyle.selectionRadius,
            style: .continuous
        )
        if isSelected {
            shape.strokeBorder(paint.selection, lineWidth: 2)
        } else if isLifted {
            shape.fill(paint.fill(paint.rowHover))
        }
    }
}

/// The current window, greyed atop All and its app's tile (#3168):
/// not a result, so the arrows, digits and search skip it, and
/// VoiceOver reads it as text, unannounced.
struct JumpYoursLine: View {
    let entry: JumpEntry
    let icon: NSImage?

    var body: some View {
        HStack(spacing: JumpRowView.spacing) {
            mark
            Text(JumpStripText.yoursTitle(entry))
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 12)
            Text(JumpStripText.yoursTag(entry))
                .font(.callout)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, JumpRowView.padding)
        .frame(height: JumpRowView.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(JumpStripText.yoursSpoken(entry))
        .accessibilityAddTraits(.isStaticText)
    }

    @ViewBuilder private var mark: some View {
        let size = JumpRowView.iconSize
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
                .opacity(0.45)
        } else {
            Color.clear.frame(width: size, height: size)
        }
    }
}
