import KiwiDeskCore
import SwiftUI

/// Shared by both drop targets (`MonitorCard`, `MainRoleCard`)
/// so the empty-state copy can't drift between them.
@MainActor private var dropHereText: String {
    L("monitor_card.drop_here", "Drop a space here")
}

/// The monitor cards (#68 §3.13): equal-sized cards in the
/// displays' physical x-order, each holding the space chips
/// that resolve to it — one representation instead of the old
/// canvas + palette + resolution list. Chips drag between
/// cards; the context menu is the keyboard/VoiceOver fallback.
struct MonitorCard: View {
    @ObservedObject var model: SettingsModel
    let display: Display
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .foregroundStyle(.secondary)
                Text(display.name)
                    .font(.caption)
                    .bold()
                    .lineLimit(1)
                if isMain {
                    BadgeChip(
                        label: L("monitor_card.main_badge", "main")
                    )
                }
            }
            Divider()
            if resolved.isEmpty {
                Text(dropHereText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                WrapChips(resolved) { entry in
                    SpaceAssignmentChip(
                        model: model,
                        space: entry.space,
                        kind: entry.kind
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(
            maxWidth: .infinity,
            minHeight: 96,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    .tint.opacity(targeted ? 1 : 0.5),
                    lineWidth: targeted ? 2 : 1
                )
        )
        .dropDestination(for: DraggableSpace.self) {
            items,
            _ in
            pin(items)
        } isTargeted: { hovering in
            targeted = hovering
        }
    }

    private var isMain: Bool {
        model.mainFingerprint == display.fingerprint
    }

    /// The spaces this card shows: pinned to this monitor, or
    /// auto-placed onto it. Main-role spaces live in the
    /// dashed "Follows main display" card instead, so every
    /// space appears exactly once (#53: no unassigned state).
    private var resolved: [SpaceAssignment] {
        model.config.spaces.compactMap { space in
            if model.config.mainSpaces.contains(space) {
                return nil
            }
            switch model.resolution(for: space) {
            case .pinned(let pin)
            where pin == display.fingerprint:
                return SpaceAssignment(
                    space: space,
                    kind: .pinned
                )
            case .auto(let resolvedTo)
            where resolvedTo == display.fingerprint:
                return SpaceAssignment(space: space, kind: .auto)
            default:
                return nil
            }
        }
    }

    /// Pins each dropped space to this monitor's fingerprint
    /// (clearing a Main assignment); the footer's profile
    /// actions persist it into the profile JSON (#36).
    private func pin(_ items: [DraggableSpace]) -> Bool {
        var assigned = false
        for item in items {
            let space = SpaceID(item.raw)
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
}

/// The dashed **Follows main display** card (#36): a space
/// dropped here follows whatever display is currently main
/// instead of freezing a fingerprint.
struct MainRoleCard: View {
    @ObservedObject var model: SettingsModel
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "macwindow.on.rectangle")
                    .foregroundStyle(.secondary)
                Text(
                    L(
                        "monitor_card.follows_main",
                        "Follows main display"
                    )
                )
                .font(.caption)
                .bold()
                .lineLimit(1)
            }
            Text(annotation)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Divider()
            if model.config.mainSpaces.isEmpty {
                Text(dropHereText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                WrapChips(
                    model.config.mainSpaces.sorted {
                        $0.raw < $1.raw
                    }
                ) { space in
                    SpaceAssignmentChip(
                        model: model,
                        space: space,
                        kind: .main
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(
            maxWidth: .infinity,
            minHeight: 96,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    .tint.opacity(targeted ? 1 : 0.5),
                    style: StrokeStyle(
                        lineWidth: targeted ? 2 : 1,
                        dash: [4]
                    )
                )
        )
        .dropDestination(for: DraggableSpace.self) {
            items,
            _ in
            assign(items)
        } isTargeted: { hovering in
            targeted = hovering
        }
    }

    /// The abstraction *and* its live resolution.
    private var annotation: String {
        guard let fingerprint = model.mainFingerprint else {
            return L("monitor_card.no_display", "no display")
        }
        return "→ " + model.monitorName(fingerprint)
    }

    private func assign(_ items: [DraggableSpace]) -> Bool {
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
