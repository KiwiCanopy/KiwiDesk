import KiwiDeskCore
import SwiftUI

/// The panel's static key hints for its scope — hidden from
/// VoiceOver, whose row actions say the same (#1875 ▸ footer).
struct JumpFooter: View {
    let scope: JumpScope
    let overflows: Bool
    /// The modifiers held now, which decide the one lit hint.
    var modifiers: NSEvent.ModifierFlags = []
    /// Whether a row or tile is selected; with none, nothing lights.
    var hasSelection = true

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
    /// The one hint in full ink: the pick that acts on the
    /// selection with the modifiers held now, read off `JumpKey`
    /// itself — ↩ where it picks, else the ⌘ digits. Navigation and
    /// bridges never light; the Shortcuts side picks nothing (#2246).
    var leading: Int? {
        guard hasSelection, scope != .shortcuts else { return nil }
        let held = modifiers.intersection([.shift, .command])
        switch JumpKey.of(keyCode: 36, modifiers: held, scope: scope) {
        // Windows: ↩ Jump, ⇧↩ Move here; Layouts: ↩ Apply.
        case .pick(let moveHere):
            guard scope == .windows else { return 1 }
            return moveHere ? 1 : 0
        default:
            break
        }
        let digit = JumpKey.of(keyCode: 18, modifiers: held, scope: scope)
        if case .quick = digit { return 2 }
        return nil
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
