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
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    var body: some View {
        capsule
            .overlay(alignment: .topTrailing) { clearBadge }
            .fixedSize()
            // The badge is a REMOVE affordance; snapshotted into
            // the lifted chip it reads as "release to clear the
            // pin", which is the opposite of what the drag does.
            .draggable(DraggableSpace(raw: space.raw)) { capsule }
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
            .onHover { hovering = $0 }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: hovering
            )
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
        .background(Capsule().fill(.tint.opacity(fillAlpha)))
        // ONE weight for every kind, the kind moving the alpha
        // alone: a closed full-perimeter edge is what makes a
        // chip read as a piece lying on the plate rather than
        // ink printed on it, which is the rest half of the drag
        // affordance (#1240). The pinned chip drew the FAINTER
        // edge at half a point, which is a half-pixel at 1x.
        .overlay(
            Capsule().strokeBorder(
                .tint.opacity(strokeAlpha),
                lineWidth: 1
            )
        )
        // A CONCRETE ink, not `.secondary`: hierarchical inks are
        // derived from the container's foreground, and this chip
        // renders under the card's drop wash and inside a
        // popover, so the one kind that was already faintest
        // dimmed further exactly while being dragged onto
        // (gui.md ▸ prefer a concrete ink).
        .foregroundStyle(
            kind == .auto
                ? AnyShapeStyle(SettingsTheme.ink2)
                : AnyShapeStyle(.primary)
        )
    }

    /// Rest fill by kind, lifted on hover.
    ///
    /// Outline-vs-fill is the ruled KIND channel, so hover must
    /// not spend it: an `.auto` chip's hover fill stays clearly
    /// under a pinned chip's REST fill, or a hovered automatic
    /// chip starts impersonating a pinned one.
    private var fillAlpha: Double {
        switch (kind == .auto, hovering) {
        case (true, false): return 0
        case (true, true): return 0.10
        case (false, false): return 0.15
        case (false, true): return 0.30
        }
    }

    /// The edge carries most of the hover, because it is the
    /// channel a filled and an unfilled chip share — and the
    /// automatic chip, which has no fill to lift, is the one
    /// most worth dragging (#1240, owner 2026-09-06: the first
    /// pass lifted the fill alone and read as nothing).
    private var strokeAlpha: Double {
        switch (kind == .auto, hovering) {
        case (true, false): return 0.65
        case (true, true): return 1.0
        case (false, false): return 0.6
        case (false, true): return 0.95
        }
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
