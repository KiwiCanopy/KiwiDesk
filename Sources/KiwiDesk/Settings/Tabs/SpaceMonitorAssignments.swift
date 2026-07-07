import KiwiDeskCore
import SwiftUI

/// The editing half of the Canvas tab (#6/#36): a palette of
/// spaces to drag onto the monitors (or Main target) above, and
/// the resolved placement per space. Drops mutate
/// `model.config.spacePins` / `mainSpaces`; the footer's profile
/// actions persist them into the profile JSON.
struct SpaceMonitorAssignments: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection("Assign spaces to monitors") {
            Text(
                "Drag a space onto a monitor to pin it to that "
                    + "hardware, or onto Main to follow the "
                    + "main display. Everything else is placed "
                    + "by the built-in default."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            palette
            Divider()
            assignments
        }
    }

    // MARK: - Palette

    private var palette: some View {
        WrapChips(model.config.spaces) { space in
            SpaceChip(label: space.raw)
                .draggable(DraggableSpace(raw: space.raw))
        }
    }

    // MARK: - Resolved placement

    @ViewBuilder
    private var assignments: some View {
        if model.config.spaces.isEmpty {
            Text("No spaces defined yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(model.config.spaces, id: \.raw) { space in
                assignmentRow(space)
            }
        }
    }

    private func assignmentRow(
        _ space: SpaceID
    ) -> some View {
        let resolution = model.resolution(for: space)
        return HStack {
            SpaceChip(label: space.raw)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.caption)
            targetLabel(resolution)
            Spacer()
            if resolution != .auto(nil), isExplicit(resolution) {
                Button {
                    model.config.spacePins[space] = nil
                    model.config.mainSpaces.remove(space)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Back to automatic placement")
            }
        }
    }

    private func isExplicit(
        _ resolution: SpaceResolution
    ) -> Bool {
        switch resolution {
        case .pinned, .main: return true
        case .auto: return false
        }
    }

    @ViewBuilder
    private func targetLabel(
        _ resolution: SpaceResolution
    ) -> some View {
        switch resolution {
        case .pinned(let fingerprint):
            Image(systemName: "display")
                .foregroundStyle(.secondary)
            Text(monitorName(fingerprint))
                .font(.system(.caption, design: .monospaced))
        case .main:
            Image(systemName: "macwindow.on.rectangle")
                .foregroundStyle(.secondary)
            Text("Main")
                .font(.caption)
                .fontWeight(.medium)
        case .auto(let fingerprint):
            Image(systemName: "wand.and.rays")
                .foregroundStyle(.tertiary)
            Text(
                "Auto → "
                    + (fingerprint.map(monitorName)
                        ?? "no display")
            )
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    /// Human-readable monitor name, falling back to the raw
    /// fingerprint when that display isn't connected.
    private func monitorName(_ fingerprint: String) -> String {
        model.displays.first {
            $0.fingerprint == fingerprint
        }?.name ?? fingerprint
    }
}
