import AppKit
import Foundation
import KiwiDeskCore
import SwiftUI

/// A drag in flight: the split the picture shows, and the snap the
/// divider took, if any.
struct AreaDividerDrag: Equatable {
    let split: ScreenSplit
    let snap: ScreenAreaSnap?
    let cut: Int
}

/// One divider of a split card (#3517 ruling 25): a hairline seam
/// with a grip at rest, the hover edge and a resize cursor under
/// the pointer, the tint while dragged. It snaps to Core's points
/// and stops at Core's floor; the draft is written on release.
struct ScreenAreaDivider: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    /// The split as stored, which the drag starts from.
    let split: ScreenSplit
    let index: Int
    let cut: ScreenAreaCut
    /// Card points per screen point.
    let scale: CGFloat
    @Binding var drag: AreaDividerDrag?
    @State private var hovering = false

    /// The drawn band the pointer can take, centred on the line.
    static let hitBand: CGFloat = 8
    /// How near, in drawn points, a snap point pulls.
    static let snapReach: CGFloat = 4
    /// A VoiceOver step, in screen points.
    static let voiceOverStep = 100

    private var sideBySide: Bool { cut.axis == .sideBySide }
    private var dragging: Bool { drag?.cut == index }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(lineStyle)
                .frame(
                    width: sideBySide ? lineWidth : nil,
                    height: sideBySide ? nil : lineWidth
                )
            Capsule()
                .fill(
                    dragging
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(SettingsTheme.ink3)
                )
                .frame(
                    width: sideBySide ? 3 : 18,
                    height: sideBySide ? 18 : 3
                )
        }
        .frame(
            width: sideBySide ? Self.hitBand : nil,
            height: sideBySide ? nil : Self.hitBand
        )
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            (inside ? cursor : .arrow).set()
        }
        .onDisappear { if hovering { NSCursor.arrow.set() } }
        .gesture(dragGesture)
        .accessibilityElement()
        .accessibilityLabel(spokenLabel)
        .accessibilityValue(spokenValue(split))
        .accessibilityAdjustableAction { direction in
            let step =
                direction == .increment
                ? Self.voiceOverStep : -Self.voiceOverStep
            let moved = split.moving(
                cut,
                to: cut.position + step,
                floor: model.areaFloor(cut.axis)
            )
            model.writeAreaSplit(moved.split, on: display)
        }
    }

    private var lineStyle: AnyShapeStyle {
        if dragging { return AnyShapeStyle(.tint) }
        return hovering
            ? AnyShapeStyle(SettingsTheme.hoverEdge)
            : AnyShapeStyle(SettingsTheme.hairline)
    }

    private var lineWidth: CGFloat {
        dragging ? 2 : hovering ? SettingsTheme.hoverEdgeStroke : 1
    }

    private var cursor: NSCursor {
        sideBySide ? .resizeLeftRight : .resizeUpDown
    }

    private var dragGesture: some Gesture {
        // Measured in the window, so the divider moving under the
        // pointer does not move the origin its translation reads.
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let along =
                    sideBySide
                    ? value.translation.width : value.translation.height
                let next = moved(by: along)
                if next.snap != nil, next.snap != drag?.snap {
                    NSHapticFeedbackManager.defaultPerformer.perform(
                        .alignment,
                        performanceTime: .now
                    )
                }
                drag = next
            }
            .onEnded { _ in
                if let drag, drag.cut == index {
                    model.writeAreaSplit(drag.split, on: display)
                }
                drag = nil
            }
    }

    /// The split with this divider dragged `along` drawn points:
    /// snapped by Core within `snapReach`, then clamped at the floor.
    private func moved(by along: CGFloat) -> AreaDividerDrag {
        let raw = cut.position + Int((along / max(scale, 0.001)).rounded())
        let extent = split.areas.map { $0.x + $0.w }.max() ?? 0
        let depth = split.areas.map { $0.y + $0.h }.max() ?? 0
        let snapped = split.snapped(
            raw,
            for: cut,
            width: extent,
            height: depth,
            tolerance: Int((Self.snapReach / max(scale, 0.001)).rounded())
        )
        let landed = split.moving(
            cut,
            to: snapped.position,
            floor: model.areaFloor(cut.axis)
        )
        let kept = landed.position == snapped.position
        return AreaDividerDrag(
            split: landed.split,
            snap: kept ? snapped.snap : nil,
            cut: index
        )
    }

    private var spokenLabel: String {
        L(
            "monitor_card.divider.ax",
            "Divider between %1$@ and %2$@",
            name(cut.leading.first),
            name(cut.trailing.first)
        )
    }

    private func name(_ id: Int?) -> String {
        id.flatMap { model.areaLabel($0, on: display) } ?? ""
    }

    private func spokenValue(_ split: ScreenSplit) -> String {
        func points(_ id: Int?) -> Int {
            split.areas.first { $0.id == id }.map {
                sideBySide ? $0.w : $0.h
            } ?? 0
        }
        return L(
            "monitor_card.divider.value.ax",
            "%1$@ %2$d points, %3$@ %4$d points",
            name(cut.leading.first),
            points(cut.leading.first),
            name(cut.trailing.first),
            points(cut.trailing.first)
        )
    }
}
