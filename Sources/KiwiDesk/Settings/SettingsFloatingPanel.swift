import KiwiDeskCore
import SwiftUI

/// Floating preview panel for narrow window widths (#678 turn 17a).
struct SettingsFloatingPanel: View {
    @ObservedObject var model: SettingsModel
    let destination: SettingsDestination
    let bounds: CGSize
    let close: () -> Void

    static let maxHeight: CGFloat = 520
    static let inset = SettingsMetrics.paneInset

    static func height(in bounds: CGSize) -> CGFloat {
        max(min(maxHeight, bounds.height - 2 * inset), 200)
    }

    /// Resting origin at trailing top corner.
    static func origin(in bounds: CGSize) -> CGPoint {
        CGPoint(
            x: bounds.width - SettingsTheme.panelWidth - inset,
            y: inset
        )
    }

    /// Clamps proposed drag offset to stay inside bounds.
    static func clamp(
        _ proposed: CGSize,
        in bounds: CGSize
    ) -> CGSize {
        let start = origin(in: bounds)
        let minX = -max(start.x - inset, 0)
        let maxY = max(
            bounds.height - height(in: bounds) - inset - start.y,
            0
        )
        return CGSize(
            width: min(max(proposed.width, minX), 0),
            height: min(max(proposed.height, 0), maxY)
        )
    }

    var body: some View {
        MovableCard(bounds: bounds, close: close) {
            SettingsDetailPanel(
                model: model,
                destination: destination
            )
        }
    }
}

/// Draggable card chrome holding stored child content (#678 turn 17a, #758).
private struct MovableCard<Content: View>: View {
    let bounds: CGSize
    let close: () -> Void
    /// Per-mount drag offset (code review, 2026-08-11).
    @State private var moved: CGSize = .zero
    @GestureState private var dragging: CGSize = .zero
    @ViewBuilder let content: Content

    private var offset: CGSize {
        SettingsFloatingPanel.clamp(
            CGSize(
                width: moved.width + dragging.width,
                height: moved.height + dragging.height
            ),
            in: bounds
        )
    }

    var body: some View {
        let start = SettingsFloatingPanel.origin(in: bounds)
        return
            card
            .frame(
                width: SettingsTheme.panelWidth,
                height: SettingsFloatingPanel.height(in: bounds)
            )
            .offset(
                x: start.x + offset.width,
                y: start.y + offset.height
            )
    }

    private var card: some View {
        VStack(spacing: 0) {
            grabBar
            content
        }
        .background(SettingsTheme.panel)
        .clipShape(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
            .strokeBorder(SettingsTheme.hairline)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: SettingsTheme.cardRadius
            )
            .strokeBorder(SettingsTheme.planeRing, lineWidth: 1)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    /// Header grab bar with distinct grip and close button
    /// (localization-auditor 2026-08-11).
    private var grabBar: some View {
        HStack(spacing: 8) {
            grip
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SettingsTheme.ink3)
            }
            .buttonStyle(.plain)
            .iconButtonAffordance(
                L("panel.hide_preview", "Hide preview")
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var grip: some View {
        Capsule()
            .fill(SettingsTheme.ink3.opacity(0.5))
            .frame(width: 34, height: 4)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($dragging) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        moved = SettingsFloatingPanel.clamp(
                            CGSize(
                                width: moved.width
                                    + value.translation.width,
                                height: moved.height
                                    + value.translation.height
                            ),
                            in: bounds
                        )
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(
                L("panel.move_preview", "Drag to move the preview")
            )
            .help(
                L("panel.move_preview", "Drag to move the preview")
            )
    }
}
