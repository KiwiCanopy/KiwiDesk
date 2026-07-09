import KiwiDeskCore
import SwiftUI

/// One space's resolved placement, split out of
/// `MonitorCards.swift` (which keeps the two drop-target cards)
/// to stay under the file-size ceiling.
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
                .help(
                    L(
                        "monitors.orphan_pin.help",
                        "Back to automatic placement"
                    )
                )
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
            return L(
                "monitor_chip.hint.pinned",
                "Pinned to this monitor — drag to move, "
                    + "ⓧ for automatic"
            )
        case .main:
            return L(
                "monitor_chip.hint.main",
                "Follows the main display — drag to pin, "
                    + "ⓧ for automatic"
            )
        case .auto:
            return L(
                "monitor_chip.hint.auto",
                "Placed automatically — drag to pin"
            )
        }
    }

    @ViewBuilder private var menu: some View {
        Button(L("monitor_chip.automatic", "Automatic")) {
            clear()
        }
        .disabled(kind == .auto)
        Button(
            L(
                "monitor_card.follows_main",
                "Follows main display"
            )
        ) {
            model.config.mainSpaces.insert(space)
            model.config.spacePins[space] = nil
        }
        .disabled(kind == .main)
        Divider()
        ForEach(model.displays, id: \.id) { display in
            Button(
                L(
                    "monitor_chip.move_to",
                    "Move to %1$@",
                    display.name
                )
            ) {
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
