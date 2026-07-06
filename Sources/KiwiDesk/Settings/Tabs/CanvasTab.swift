import KiwiDeskCore
import SwiftUI

/// Tab 2 — Workspace & Monitor Mapping: a scaled canvas of the
/// connected monitors, each labeled with its fingerprint and the
/// virtual spaces assigned to it (05_GUI_Concept §2, Tab 2).
/// Spaces are dragged from the palette below onto a monitor to
/// author `space_monitor_map` (#6); `SpaceMonitorAssignments`
/// hosts the palette and the unassign list.
struct CanvasTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection("Monitor layout") {
                    if model.displays.isEmpty {
                        Text("No monitors detected.")
                            .foregroundStyle(.secondary)
                    } else {
                        MonitorCanvas(model: model)
                            .frame(height: 260)
                    }
                }
                if !model.displays.isEmpty {
                    SpaceMonitorAssignments(model: model)
                }
                fingerprintSection
            }
            .padding(16)
        }
    }

    private var fingerprintSection: some View {
        SettingsSection("Monitor fingerprints") {
            Text(
                "Profiles reattach automatically when a known "
                    + "monitor setup is reconnected."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(model.displays, id: \.id) { display in
                HStack {
                    Image(systemName: "display")
                        .foregroundStyle(.secondary)
                    Text(display.name)
                    Spacer()
                    Text(display.fingerprint)
                        .font(
                            .system(.caption, design: .monospaced)
                        )
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

/// Draws each display as a proportionally placed rectangle that
/// accepts dropped spaces (#6).
private struct MonitorCanvas: View {
    @ObservedObject var model: SettingsModel
    @State private var targeted: DisplayID?

    var body: some View {
        GeometryReader { geo in
            let bounds = unionFrame
            let scale = fitScale(bounds, into: geo.size)
            ForEach(model.displays, id: \.id) { display in
                monitorTile(display)
                    .frame(
                        width: display.frame.width * scale,
                        height: display.frame.height * scale
                    )
                    .position(
                        x: (display.frame.midX - bounds.minX)
                            * scale,
                        y: (display.frame.midY - bounds.minY)
                            * scale
                    )
            }
        }
    }

    private func monitorTile(_ display: Display) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        .tint.opacity(
                            targeted == display.id ? 1 : 0.6
                        ),
                        lineWidth: targeted == display.id ? 2 : 1
                    )
            )
            .overlay(
                VStack(spacing: 2) {
                    Text(display.name)
                        .font(.caption).bold()
                        .lineLimit(1)
                    Text(spacesLabel(display))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(4)
            )
            .dropDestination(for: DraggableSpace.self) {
                items,
                _ in
                assign(items, to: display)
            } isTargeted: { hovering in
                targeted = hovering ? display.id : nil
            }
    }

    /// Pins each dropped space to this monitor's fingerprint as a
    /// single-element chain; the footer Save persists it.
    private func assign(
        _ items: [DraggableSpace],
        to display: Display
    ) -> Bool {
        guard !items.isEmpty else { return false }
        for item in items {
            model.config.spaceMonitorMap[SpaceID(item.raw)] =
                [display.fingerprint]
        }
        return true
    }

    /// The spaces authored onto this monitor (its fingerprint is
    /// first in their chain), not merely where they live now.
    private func spacesLabel(_ display: Display) -> String {
        let spaces = model.config.spaceMonitorMap.keys
            .filter {
                model.config.spaceMonitorMap[$0]?.first
                    == display.fingerprint
            }
            .map(\.raw)
            .sorted()
        guard !spaces.isEmpty else { return "drop a space" }
        return "spaces " + spaces.joined(separator: ", ")
    }

    /// The bounding box of every display frame.
    private var unionFrame: CGRect {
        model.displays
            .map(\.frame)
            .reduce(CGRect.null) { $0.union($1) }
    }

    private func fitScale(
        _ bounds: CGRect,
        into size: CGSize
    ) -> CGFloat {
        guard bounds.width > 0, bounds.height > 0 else {
            return 1
        }
        let padding: CGFloat = 16
        let sx = (size.width - padding) / bounds.width
        let sy = (size.height - padding) / bounds.height
        return min(sx, sy)
    }
}
