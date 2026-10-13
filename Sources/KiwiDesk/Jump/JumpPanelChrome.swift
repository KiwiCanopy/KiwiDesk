import KiwiDeskCore
import SwiftUI

/// The panel's static key hints for its scope — hidden from
/// VoiceOver, whose row actions say the same (#1875 ▸ footer).
struct JumpFooter: View {
    let scope: JumpScope
    let overflows: Bool
    /// ⇧ held: "⇧↩ Move here" takes the full ink from "↩ Jump",
    /// the field no longer previewing it (#2246).
    var shiftHeld = false

    var body: some View {
        HStack(spacing: 8) {
            // Worded rather than positional, so it stays true at
            // any scroll offset — the shortcuts panel's cue (#1292).
            if overflows, scope == .windows {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                    Text(JumpRowText.scrollHint)
                }
                Text(verbatim: "·")
            }
            ForEach(Array(hints.enumerated()), id: \.offset) { index, hint in
                if index > 0 { Text(verbatim: "·") }
                Text(hint)
                    .foregroundStyle(
                        index == leading
                            ? AnyShapeStyle(.primary)
                            : AnyShapeStyle(.secondary)
                    )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .accessibilityHidden(true)
    }
}

extension JumpFooter {
    /// The hint ↩ acts by now, in full ink: Jump, or Move here
    /// while ⇧ is held. The other sides lead with none.
    var leading: Int? {
        guard scope == .windows else { return nil }
        return shiftHeld ? 1 : 0
    }

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
                L("jump.footer.quick", "%1$@ Quick jump", "⌘1–9"),
                other,
            ]
        case .shortcuts:
            return [
                L("shortcuts.footer.edit", "%1$@ Edit", "⌘,"),
                other,
            ]
        case .layouts:
            return [
                L("layout_picker.footer.choose", "%1$@ Choose", "← →"),
                L("layout_picker.footer.apply", "%1$@ Apply", "↩"),
                L(
                    "layout_picker.footer.quick",
                    "%1$@ Quick apply",
                    "⌘1–\(LayoutMode.allCases.count)"
                ),
                other,
            ]
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
