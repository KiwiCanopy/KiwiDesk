import KiwiDeskCore
import SwiftUI

/// The panel's static key hints for its scope — hidden from
/// VoiceOver, whose row actions say the same (#1875 ▸ footer);
/// the scroll cue is spoken. Short of room, it sheds hints from
/// the end, then truncates the scroll cue; a hint keeps its index,
/// so the lit one stays lit while it is shown.
struct JumpFooter: View {
    let scope: JumpScope
    /// Whether the side runs past what it shows.
    let overflows: Bool
    /// The modifiers held now, which decide the one lit hint.
    var modifiers: NSEvent.ModifierFlags = []
    /// Whether a row or tile is selected; with none, nothing lights.
    var hasSelection = true
    /// How many items the View side's ⌘ digits reach on the
    /// selected line (#2309 ruling 7).
    var quickCount = 9
    /// Whether ↩ turns KiwiVision off, which the lit hint then
    /// says instead of Apply (#2103 ruling 56).
    var turnsOff = false

    var body: some View {
        let hints = hints
        ViewThatFits(in: .horizontal) {
            ForEach((0...hints.count).reversed(), id: \.self) {
                row(Array(hints.prefix($0)))
            }
            // Past every candidate the cue truncates rather than
            // spill onto the side's controls.
            row([], fixed: false)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// One candidate line: the scroll cue, then `shown`; a line
    /// that is not `fixed` truncates to the room it is given.
    func row(_ shown: [String], fixed: Bool = true) -> some View {
        HStack(spacing: 8) {
            // The Shortcuts side draws its cue in the leading slot.
            if overflows, scope != .shortcuts, let cue = scrollHint {
                JumpScrollCue(text: cue)
                if !shown.isEmpty {
                    Text(verbatim: "·").accessibilityHidden(true)
                }
            }
            ForEach(Array(shown.enumerated()), id: \.offset) { index, hint in
                if index > 0 { Text(verbatim: "·") }
                Text(hint)
                    .foregroundStyle(
                        index == leading
                            ? AnyShapeStyle(.primary)
                            : AnyShapeStyle(.secondary)
                    )
            }
            .accessibilityHidden(true)
        }
        .fixedSize(horizontal: fixed, vertical: false)
    }

    /// The side's scroll cue; the View side never scrolls.
    var scrollHint: String? { Self.scrollHint(for: scope) }

    static func scrollHint(for scope: JumpScope) -> String? {
        switch scope {
        case .windows:
            return JumpRowText.scrollHint
        case .shortcuts:
            return L(
                "shortcuts.panel.scroll_hint",
                "Scroll for more shortcuts"
            )
        case .view:
            return nil
        }
    }
}

extension JumpFooter {
    /// The one hint in full ink: the pick that acts on the
    /// selection with the modifiers held now, read off `JumpKey`
    /// itself — ↩ where it picks, else the ⌘ digits. Navigation and
    /// bridges never light; the Shortcuts side picks nothing (#2246).
    /// The index is into `hints`, whose order it follows: Jump,
    /// Move here, the digits on Windows; Apply, the digits on View.
    var leading: Int? {
        guard hasSelection, scope != .shortcuts else { return nil }
        let held = modifiers.intersection([.shift, .command])
        switch JumpKey.of(
            keyCode: JumpKey.returnKey,
            modifiers: held,
            scope: scope
        ) {
        // Windows: ↩ Jump, ⇧↩ Move here; View: ↩ Apply.
        case .pick(let moveHere):
            guard scope == .windows else { return moveHere ? nil : 0 }
            return moveHere ? 1 : 0
        default:
            break
        }
        let one = UInt16(JumpKey.digitRows[0])
        let digit = JumpKey.of(keyCode: one, modifiers: held, scope: scope)
        guard case .quick(_, let moveHere) = digit else { return nil }
        if scope == .windows { return 2 }
        return moveHere ? nil : 1
    }

    private var shiftHeld: Bool { modifiers.contains(.shift) }

    var hints: [String] {
        let other = L(
            "jump.footer.scope",
            "%1$@ %2$@",
            "⇥",
            scope.stepped(forward: true).title
        )
        switch scope {
        case .windows:
            return [
                L("jump.footer.jump", "%1$@ Jump", "↩"),
                L("jump.footer.move_here", "%1$@ Move here", "⇧↩"),
                // ⇧ already rewrites the digits to what they then
                // do; ⌘ joining only lights them.
                shiftHeld
                    ? L(
                        "jump.footer.quick_move_here",
                        "%1$@ Quick move here",
                        "⇧⌘1–9"
                    )
                    : L("jump.footer.quick", "%1$@ Quick jump", "⌘1–9"),
                other,
            ]
        case .shortcuts:
            // Edit in Settings… stands beside the hints with its
            // own chord.
            return [other]
        case .view:
            let digits = quickCount > 1 ? "⌘1–\(quickCount)" : "⌘1"
            let apply =
                turnsOff
                ? ViewPickText.turnOffFooter
                : L("layout_picker.footer.apply", "%1$@ Apply", "↩")
            let quick = L(
                "layout_picker.footer.quick",
                "%1$@ Quick apply",
                digits
            )
            // Nothing matched: no digit reaches anything.
            return quickCount > 0
                ? [apply, quick, ViewPickText.lineHint("↑↓"), other]
                : [apply, ViewPickText.lineHint("↑↓"), other]
        }
    }
}

/// A side's scroll cue, worded rather than positional so it stays
/// true at any scroll offset (#1292); spoken, its chevron silent.
struct JumpScrollCue: View {
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.down")
                .accessibilityHidden(true)
            Text(text)
        }
    }
}

/// The scope switch at the field's trailing end (#2229): a click
/// target and a mark of where ⇥ goes. The panel reads Tab ahead of
/// every view, so the field keeps the keys. Each side prints its
/// own shortcut's live chord (#2245).
struct JumpScopeSwitch: View {
    @ObservedObject var model: JumpModel

    var body: some View {
        SegmentedPicker(
            spokenLabel: JumpScope.switchName,
            reservesWeight: true,
            hints: model.chords,
            spokenHint: LayoutPickText.chordHint,
            selection: Binding(
                get: { model.scope },
                set: { model.setScope($0) }
            ),
            options: JumpScope.allCases.map { ($0.title, $0) }
        )
        .controlSize(.small)
        .fixedSize()
    }
}
