import KiwiDeskCore
import SwiftUI

/// The editing half of the Canvas tab (#6): a palette of spaces
/// to drag onto the monitors above, and the resulting
/// `space_monitor_map` assignments with an unassign control.
/// Drops mutate `model.config.spaceMonitorMap`; the footer Save
/// persists them to `init.lua`.
struct SpaceMonitorAssignments: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        SettingsSection("Assign spaces to monitors") {
            Text(
                "Drag a space onto a monitor above to pin it "
                    + "there. Assignments are saved to "
                    + "space_monitor_map."
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

    // MARK: - Assignments

    @ViewBuilder
    private var assignments: some View {
        let rows = assignedRows
        if rows.isEmpty {
            Text("No assignments yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(rows, id: \.space.raw) { row in
                assignmentRow(row)
            }
        }
    }

    private func assignmentRow(
        _ row: AssignedRow
    ) -> some View {
        HStack {
            SpaceChip(label: row.space.raw)
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .font(.caption)
            Image(systemName: "display")
                .foregroundStyle(.secondary)
            Text(row.monitor)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            Button {
                model.config.spaceMonitorMap[row.space] = nil
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Unassign")
        }
    }

    /// Resolves each assigned space to a human-readable monitor
    /// name, falling back to the raw fingerprint when the mapped
    /// display isn't currently connected.
    private var assignedRows: [AssignedRow] {
        model.config.spaceMonitorMap.keys
            .sorted { $0.raw < $1.raw }
            .compactMap { space in
                guard
                    let chain = model.config.spaceMonitorMap[
                        space
                    ], let fingerprint = chain.first
                else { return nil }
                let name =
                    model.displays.first {
                        $0.fingerprint == fingerprint
                    }?.name ?? fingerprint
                return AssignedRow(space: space, monitor: name)
            }
    }

    private struct AssignedRow {
        let space: SpaceID
        let monitor: String
    }
}

/// A pill rendering a space name, shared by the palette and the
/// assignment rows.
struct SpaceChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(.tint.opacity(0.15))
            )
            .overlay(
                Capsule().strokeBorder(.tint.opacity(0.4))
            )
    }
}

/// A simple left-to-right flowing row of chips that wraps to the
/// next line when it runs out of width.
struct WrapChips<Item, Chip: View>: View {
    private let items: [Item]
    private let chip: (Item) -> Chip

    init(
        _ items: [Item],
        @ViewBuilder chip: @escaping (Item) -> Chip
    ) {
        self.items = items
        self.chip = chip
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) {
                _,
                item in
                chip(item)
            }
        }
    }
}
