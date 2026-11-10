import AppKit
import KiwiDeskCore
import SwiftUI

/// The Windows side's app strip (#3135): All, then the recent apps,
/// above the list. It scrolls sideways with fades and follows the
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
/// count capsule for two or more windows, never red. The selected
/// tile takes the hover ground, its ink and a 2 pt accent caret; a
/// lifted one the ground and ink alone.
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

    static let width: CGFloat = 76
    static let iconSize: CGFloat = 32
    static let caret: CGFloat = 2

    var body: some View {
        Button(action: onActivate) {
            // A selected or lifted tile sits on the hover ground and
            // takes its measured ink; the accent stays a fill.
            content.kiwiHubRowInk(
                paint,
                selected: false,
                lifted: isSelected || isLifted
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
            Capsule()
                .fill(isSelected ? paint.selection : .clear)
                .frame(width: Self.iconSize, height: Self.caret)
        }
        .padding(.top, 6)
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
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(paint.fill(paint.rowHover))
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
                .background(Capsule().fill(paint.fill(paint.rowHover)))
                .offset(x: 8, y: -4)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var ground: some View {
        if isSelected || isLifted {
            RoundedRectangle(
                cornerRadius: KeyPanelStyle.selectionRadius,
                style: .continuous
            )
            .fill(paint.fill(paint.rowHover))
        }
    }
}

/// The list's one row for an app the strip lists with no window
/// (#3135): "No windows", dimmed, on the selection's hover ground,
/// and its pick — ↩, a click or VoiceOver — reopens the app.
struct JumpReopenRow: View {
    let text: String
    let app: String
    let onActivate: () -> Void
    @Environment(\.kiwiHubPaint) private var paint

    var body: some View {
        Button(action: onActivate) {
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: JumpRowView.height)
                .background(
                    RoundedRectangle(
                        cornerRadius: KeyPanelStyle.selectionRadius,
                        style: .continuous
                    )
                    .fill(paint.fill(paint.rowHover))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .accessibilityLabel(JumpStripText.moved(tile: app, row: text))
        .accessibilityHint(JumpStripText.reopenHint)
        .accessibilityAddTraits(.isSelected)
    }
}
