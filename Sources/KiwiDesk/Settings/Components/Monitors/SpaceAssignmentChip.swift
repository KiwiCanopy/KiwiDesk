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

/// One space chip inside a display card. Semantic micro-icons
/// (pin / arrow) encode the resolution kind — border style alone
/// would be an accessibility risk (§3.13). Explicit chips clear
/// back to automatic via an always-visible ⓧ (a reserved trailing
/// slot, like a Mail address token — a hover-only button grew the
/// chip after the flow layout had sized it, so its ⓧ overflowed a
/// narrow card).
///
/// **The chip is a `Menu`, which is what makes the keyboard route
/// real** (#678 turn 13b). This docstring used to call the
/// context menu "the keyboard-navigable fallback for every move"
/// while the chip was an `HStack` with a `.draggable` on it: not
/// focusable, no Tab stop, no Return, and nothing for VoiceOver
/// to activate — so the promise was false for exactly the users
/// it was written for. A `Menu` earns focus, keyboard activation
/// and the VoiceOver trait from AppKit.
///
/// All three routes stay live: click or Return opens the menu,
/// right-click opens the same one, and drag remains the pointing
/// route. The `.contextMenu` is kept deliberately — dropping it
/// with the rewrite would have retired a gesture people already
/// had, as a side effect rather than a decision.
struct SpaceAssignmentChip: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    let kind: SpaceAssignment.Kind
    /// The displays the "move to…" menu offers, in the picture's
    /// own left-to-right order — passed in from the area's row
    /// expansion rather than re-read here, so the menu and the
    /// cards can never list different monitors.
    let displays: [Display]

    var body: some View {
        Menu {
            menu
        } label: {
            capsule
        }
        .menuStyle(.borderlessButton)
        .neutralMenuLabel()
        .menuIndicator(.hidden)
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
        // Right-click keeps working. Making the chip a `Menu`
        // dropped the `.contextMenu` it used to carry, which
        // silently retired the gesture people already had — a
        // side effect of fixing the keyboard route, never a
        // decision (docs review, 2026-08-04). Both open the same
        // menu.
        .contextMenu { menu }
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
                    // The glyph outranks the name (#545).
                    // `FlowLayout` measures this chip at its
                    // ideal size and then re-proposes exactly
                    // that, so any rounding shortfall is taken
                    // from a flexible child — and at equal
                    // priority that was the emoji, which cannot
                    // shrink and so clipped. The name absorbs it
                    // instead, which it already does by design
                    // (it truncates into the row's tooltip).
                    //
                    // Priority, not `.fixedSize()`: an icon is
                    // one character only by the GUI picker's
                    // rule, never Lua's (`set_space_icon` takes
                    // any string — the GUI curates, Lua is
                    // open), and a fixed-size glyph would let a
                    // long one push the whole chip wide.
                    .layoutPriority(1)
            }
            Text(space.raw)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
                // Provisional cap; the full name lives in the
                // tooltip when elided. Re-evaluate with the
                // 8-language add (#95) — localized names run
                // longer.
                .frame(maxWidth: 120, alignment: .leading)
            if kind != .auto {
                Button {
                    clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        // A 9 pt glyph inside a draggable surface
                        // is a click that starts a drag two points
                        // off centre. The hit target is the
                        // affordance, not the drawing.
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
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        // Fill says EXPLICIT, outline says automatic — shape, not
        // opacity. A dimmed chip spends this app's inert
        // vocabulary (`GreyOut`) on something fully draggable,
        // which reads as "you cannot move this" about the one
        // chip most worth moving.
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
    }

    /// One glyph per kind, and the follows-main one is an ARROW
    /// (#678 turn 13b): the tray it belongs to is dashed and sits
    /// off the main display, and an arrow says "goes wherever
    /// that is" where the old link glyph said only "attached to
    /// something" — the tray's own header carries the same arrow,
    /// so the concept has one glyph rather than three. Automatic
    /// carries none: a chip placed by a default is the absence of
    /// a decision, and the outline-only capsule says so.
    private var icon: String? {
        switch kind {
        case .pinned: return "pin.fill"
        case .main: return "arrow.right"
        case .auto: return nil
        }
    }

    /// The hints name the CLEAR BUTTON rather than drawing a "ⓧ"
    /// in prose: the button renders `xmark.circle.fill`, so the
    /// character was already an approximation of it, and a glyph
    /// inside a translated sentence is one more thing a catalog
    /// can lose.
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
        // Only the displays this space could MOVE to: the one it
        // already sits on is not a move, and on a one-display Mac
        // the whole list is the display it is already on.
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

    /// The fingerprint this chip is drawn on, when it is drawn on
    /// one: a follows-main chip lives in the tray rather than on
    /// a display, so every display is a move for it.
    private var currentFingerprint: String? {
        kind == .main ? nil : model.config.spacePins[space]
    }

    private func clear() {
        model.config.spacePins[space] = nil
        model.config.mainSpaces.remove(space)
    }
}
