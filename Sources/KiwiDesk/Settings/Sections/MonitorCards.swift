import KiwiDeskCore
import SwiftUI

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
                if isMain { BadgeChip(label: "main") }
            }
            Divider()
            if resolved.isEmpty {
                Text("Drop a space here")
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
                Text("Follows main display")
                    .font(.caption)
                    .bold()
                    .lineLimit(1)
            }
            Text(annotation)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Divider()
            if model.config.mainSpaces.isEmpty {
                Text("Drop a space here")
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
            return "no display"
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

struct SpaceAssignment: Identifiable {
    enum Kind {
        case pinned
        case auto
        case main
    }

    let space: SpaceID
    let kind: Kind
    var id: String { space.raw }
}

/// One space chip inside a monitor card. Semantic micro-icons
/// (pin/link) encode the resolution kind — border style alone
/// would be an accessibility risk (§3.13); auto chips render
/// dimmed. Explicit chips clear back to automatic via ⓧ on
/// hover; the context menu is the keyboard-navigable fallback
/// for every move.
struct SpaceAssignmentChip: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    let kind: SpaceAssignment.Kind
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8))
            }
            if let spaceIcon = model.config.settings
                .spaceIcons[space]
            {
                IconGlyphLabel(icon: spaceIcon)
                    .font(.system(size: 10))
            }
            Text(space.raw)
                .font(.caption)
                .fontWeight(.medium)
            if kind != .auto, hovering {
                Button {
                    clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                }
                .buttonStyle(.borderless)
                .help("Back to automatic placement")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.tint.opacity(0.15)))
        .overlay(
            Capsule().strokeBorder(.tint.opacity(0.4))
        )
        .opacity(kind == .auto ? 0.55 : 1)
        .onHover { hovering = $0 }
        .draggable(DraggableSpace(raw: space.raw))
        .help(hint)
        .contextMenu { menu }
    }

    private var icon: String? {
        switch kind {
        case .pinned: return "pin.fill"
        case .main: return "link"
        case .auto: return nil
        }
    }

    private var hint: String {
        switch kind {
        case .pinned:
            return "Pinned to this monitor — drag to move, "
                + "ⓧ for automatic"
        case .main:
            return "Follows the main display — drag to pin, "
                + "ⓧ for automatic"
        case .auto:
            return "Placed automatically — drag to pin"
        }
    }

    @ViewBuilder private var menu: some View {
        Button("Automatic") { clear() }
            .disabled(kind == .auto)
        Button("Follows main display") {
            model.config.mainSpaces.insert(space)
            model.config.spacePins[space] = nil
        }
        .disabled(kind == .main)
        Divider()
        ForEach(model.displays, id: \.id) { display in
            Button("Move to \(display.name)") {
                model.config.spacePins[space] =
                    display.fingerprint
                model.config.mainSpaces.remove(space)
            }
        }
    }

    private func clear() {
        model.config.spacePins[space] = nil
        model.config.mainSpaces.remove(space)
    }
}
