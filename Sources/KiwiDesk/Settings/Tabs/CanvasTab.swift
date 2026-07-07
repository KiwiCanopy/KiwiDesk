import KiwiDeskCore
import SwiftUI

/// Tab 2 — Workspace & Monitor Mapping: a scaled canvas of the
/// connected monitors, each labeled with its fingerprint and the
/// virtual spaces resolved onto it (05_GUI_Concept §2, Tab 2).
/// Spaces dragged onto a monitor tile pin to that hardware;
/// dropped onto the **Main** target they follow whatever display
/// is main (#36). `SpaceMonitorAssignments` hosts the palette
/// and the per-space resolution list.
struct CanvasTab: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if model.editingStoredProfile
                    && !model.placementEditable
                {
                    // Editing a stored profile whose monitors
                    // aren't attached: there is no live geometry
                    // to render, so placement is read-only here
                    // (#18). The other tabs still edit it.
                    placementUnavailable
                } else {
                    SettingsSection("Monitor layout") {
                        if model.displays.isEmpty {
                            Text("No monitors detected.")
                                .foregroundStyle(.secondary)
                        } else {
                            MonitorCanvas(model: model)
                                .frame(height: 260)
                            MainDropTarget(model: model)
                        }
                    }
                    if !model.displays.isEmpty {
                        SpaceMonitorAssignments(model: model)
                    }
                    // Native-Space bindings are global, not part
                    // of a profile — only offered in live editing.
                    if !model.editingStoredProfile {
                        NativeSpacesSection(model: model)
                    }
                    fingerprintSection
                }
            }
            .padding(16)
        }
    }

    private var placementUnavailable: some View {
        SettingsSection("Monitor layout") {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "Monitors not connected",
                    systemImage:
                        "display.trianglebadge.exclamationmark"
                )
                .font(.headline)
                Text(
                    "This profile's monitors aren't attached "
                        + "right now, so its space placement "
                        + "can't be edited here. Connect its "
                        + "monitor setup to arrange spaces — the "
                        + "other tabs still edit this profile."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
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

    /// Pins each dropped space to this monitor's fingerprint
    /// (clearing a Main assignment); the footer's profile
    /// actions persist it into the profile JSON (#36).
    private func assign(
        _ items: [DraggableSpace],
        to display: Display
    ) -> Bool {
        guard !items.isEmpty else { return false }
        var assigned = false
        for item in items {
            let space = SpaceID(item.raw)
            // The palette only vends defined spaces; reject any
            // stray payload so the map never gains an orphan key.
            guard model.config.spaces.contains(space) else {
                continue
            }
            model.config.spacePins[space] =
                display.fingerprint
            model.config.mainSpaces.remove(space)
            assigned = true
        }
        return assigned
    }

    /// The spaces this monitor *resolves* — pins, Main-role
    /// spaces (when it is main), and positional defaults — not
    /// merely where windows live now. There is no unassigned
    /// state (#53).
    private func spacesLabel(_ display: Display) -> String {
        let spaces = model.config.spaces
            .filter { space in
                switch model.resolution(for: space) {
                case .pinned(let pin):
                    return pin == display.fingerprint
                case .main:
                    return model.mainFingerprint
                        == display.fingerprint
                case .auto(let resolved):
                    return resolved == display.fingerprint
                }
            }
            .map(\.raw)
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

/// The **Main** drop target (#36): a space dropped here follows
/// whatever display is currently main (resolved live via the
/// system's main-display id), instead of freezing a fingerprint.
/// Same drag gesture as the monitor tiles, second destination.
private struct MainDropTarget: View {
    @ObservedObject var model: SettingsModel
    @State private var targeted = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "macwindow.on.rectangle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Main").font(.caption).bold()
                Text(annotation)
                    .font(
                        .system(.caption2, design: .monospaced)
                    )
                    .foregroundStyle(.secondary)
            }
            Spacer()
            mainSpaceChips
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    .tint.opacity(targeted ? 1 : 0.6),
                    style: StrokeStyle(
                        lineWidth: targeted ? 2 : 1,
                        dash: [4]
                    )
                )
        )
        .dropDestination(for: DraggableSpace.self) { items, _ in
            assignToMain(items)
        } isTargeted: { hovering in
            targeted = hovering
        }
    }

    /// The abstraction *and* its live resolution.
    private var annotation: String {
        guard let fingerprint = model.mainFingerprint else {
            return "no display"
        }
        return "→ \(fingerprint)"
    }

    private var mainSpaceChips: some View {
        WrapChips(
            model.config.mainSpaces.sorted { $0.raw < $1.raw }
        ) { space in
            SpaceChip(label: space.raw)
        }
    }

    private func assignToMain(
        _ items: [DraggableSpace]
    ) -> Bool {
        guard !items.isEmpty else { return false }
        var assigned = false
        for item in items {
            let space = SpaceID(item.raw)
            guard model.config.spaces.contains(space) else {
                continue
            }
            model.config.mainSpaces.insert(space)
            model.config.spacePins[space] = nil
            assigned = true
        }
        return assigned
    }
}
