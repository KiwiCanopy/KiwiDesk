import KiwiDeskCore
import SwiftUI

/// One space's resolved placement: which display it lands on and
/// whether a person or a default put it there.
struct SpaceAssignment: Identifiable, Hashable {
    enum Kind: Hashable {
        case pinned
        case auto
        case main
    }

    let space: SpaceID
    let kind: Kind
    var id: String { space.raw }
}

/// Space chip displaying placement on a monitor card (#758).
///
/// Supports drag, context menu, VoiceOver actions, and keyboard menu chord
/// via `.rowActions` (#678, #845).
/// Explicit chips clear to automatic via corner badge.
struct SpaceAssignmentChip: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    let kind: SpaceAssignment.Kind
    /// Target displays for move actions in picture order.
    let displays: [Display]
    @FocusState private var focused: Bool

    var body: some View {
        capsule
            .fixedSize()
            .draggable(DraggableSpace(raw: space.raw))
            .help(
                L(
                    "monitor_chip.help_full",
                    "%1$@\n%2$@",
                    space.raw,
                    hint
                )
            )
            .accessibilityLabel(space.raw)
            .accessibilityValue(hint)
            .focusable()
            .focused($focused)
            // A click must not ring the chip (#996 ruling,
            // owner 2026-09-01). Wired here rather than shared:
            // a modifier handed the binding never fires.
            .onChange(of: focused) { _, now in
                guard now, ClickBornFocus.isClickBorn else {
                    return
                }
                focused = false
            }
            .rowActions { menu }
    }

    private var capsule: some View {
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
                    // Glyph outranks name on overflow (#545).
                    .layoutPriority(1)
            }
            Text(space.raw)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120, alignment: .leading)
        }
        .padding(.leading, 8)
        .padding(.trailing, kind == .auto ? 8 : 14)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(
                .tint.opacity(kind == .auto ? 0 : 0.15)
            )
        )
        .overlay(
            Capsule().strokeBorder(
                .tint.opacity(kind == .auto ? 0.35 : 0.5),
                lineWidth: kind == .auto ? 1 : 0.5
            )
        )
        .foregroundStyle(
            kind == .auto
                ? AnyShapeStyle(.secondary)
                : AnyShapeStyle(.primary)
        )
        .overlay(alignment: .topTrailing) { clearBadge }
    }

    /// Clear-pin button overlay on trailing-top corner (#758).
    @ViewBuilder private var clearBadge: some View {
        if kind != .auto {
            Button {
                clear()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        SettingsTheme.card,
                        SettingsTheme.ink2
                    )
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .iconButtonAffordance(
                L(
                    "monitors.clear_pin.label",
                    "Back to automatic placement"
                )
            )
            .offset(x: 4, y: -2)
        }
    }

    /// Semantic micro-icon for assignment kind (#678).
    private var icon: String? {
        switch kind {
        case .pinned: return "pin.fill"
        case .main: return "arrow.right"
        case .auto: return nil
        }
    }

    private var hint: String {
        switch kind {
        case .pinned:
            return L(
                "monitor_chip.hint.pinned",
                "Pinned to this monitor — drag to move, or "
                    + "clear it for automatic"
            )
        case .main:
            return L(
                "monitor_chip.hint.main",
                "Follows the main display — drag to pin, or "
                    + "clear it for automatic"
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
        let elsewhere = displays.filter {
            $0.fingerprint != currentFingerprint
        }
        if !elsewhere.isEmpty {
            Divider()
            ForEach(elsewhere, id: \.id) { display in
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
    }

    private var currentFingerprint: String? {
        kind == .main ? nil : model.config.spacePins[space]
    }

    private func clear() {
        model.config.spacePins[space] = nil
        model.config.mainSpaces.remove(space)
    }
}
