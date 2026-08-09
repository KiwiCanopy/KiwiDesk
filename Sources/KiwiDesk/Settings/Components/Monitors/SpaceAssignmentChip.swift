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
/// back to automatic via an always-visible ⓧ drawn as a CORNER
/// BADGE overlay on the trailing-top corner (#758): an overlay
/// never contributes to the parent's size, so the chip's metrics
/// stop depending on whether it is pinned. Its two ancestors
/// died of the same measurement — a hover-only button grew the
/// chip after the flow layout had sized it, so its ⓧ overflowed
/// a narrow card, and the in-flow trailing slot that replaced it
/// ate label width on every pinned chip and made each read as a
/// delete button.
///
/// **A `Menu` inside the chip is what makes the keyboard route
/// real** (#678 turn 13b). Before it, the chip was an `HStack`
/// with a `.draggable`: not focusable, no Tab stop, no Return,
/// nothing for VoiceOver to activate — so the docstring's promise
/// of a "keyboard-navigable fallback" was false for exactly the
/// users it was written for. A `Menu` earns focus, keyboard
/// activation and the VoiceOver trait from AppKit.
///
/// 13b gave the menu the WHOLE chip, which cost the drag: a
/// borderless menu consumes the mouse-down to open itself, so
/// `.draggable` never saw a press to begin from.
///
/// **Two routes now, and the keyboard one is knowingly gone**
/// (owner ruling 2026-08-04): drag the chip, or right-click it.
/// A visible chevron carrying the `Menu` was tried in between and
/// rejected as clutter — first beside the pill, then inside it.
/// The cost is the one 13b was written to fix: `.contextMenu` has
/// no keyboard or VoiceOver equivalent, so "move this space to
/// another display" is once again pointer-only. Anyone restoring
/// a keyboard route should read 13b's argument before reaching
/// for a whole-chip `Menu` again — that is what took the drag.
struct SpaceAssignmentChip: View {
    @ObservedObject var model: SettingsModel
    let space: SpaceID
    let kind: SpaceAssignment.Kind
    /// The displays the "move to…" menu offers, in the picture's
    /// own left-to-right order — passed in from the area's row
    /// expansion rather than re-read here, so the menu and the
    /// cards can never list different monitors.
    let displays: [Display]

    /// A plain draggable chip with a context menu — no `Menu`
    /// anywhere in it, which is the only way the drag works at
    /// all (see the type's docstring).
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
        }
        .padding(.leading, 8)
        // The clear badge rides the trailing-top corner, so a
        // pinned chip's content earns extra trailing room — at
        // the symmetric 8 the disc sat ON the space number
        // (owner, 2026-08-09).
        .padding(.trailing, kind == .auto ? 8 : 14)
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
        // Always visible, never hover-revealed: a hover-inserted
        // control changes the pill's size, which is the trap the
        // overlay exists to close — hover may change only the
        // badge's tint, never its presence or any metric.
        .overlay(alignment: .topTrailing) { clearBadge }
    }

    /// The clear-pin control, riding the trailing-top corner and
    /// slightly overlapping the border. In the accessibility
    /// tree at full strength however quietly it draws: the
    /// 16 × 16 hit target (the affordance is the target, not the
    /// 9 pt glyph), the spoken label and keyboard reachability
    /// all survive the move out of the flow (#758).
    @ViewBuilder private var clearBadge: some View {
        if kind != .auto {
            Button {
                clear()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    // Grey disc, light x — the NSSearchField
                    // cancel shape. The chip renders on three
                    // surfaces (card plate, the tray's bare
                    // well, the overflow popover), and a
                    // card-coloured disc is invisible by
                    // construction on the first and a punched
                    // hole on the second; an ink2 disc reads on
                    // all three, masks whatever stroke it
                    // overlaps, and separates by lightness, not
                    // hue (ui-designer, 2026-08-09).
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
            // y −2, not −4: the 16 pt hit target's top edge
            // stays inside `stackSpacing`'s gap, so a click on
            // the tail of a truncated header name cannot land
            // on "clear this pin" (ui-designer, 2026-08-09).
            .offset(x: 4, y: -2)
        }
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
