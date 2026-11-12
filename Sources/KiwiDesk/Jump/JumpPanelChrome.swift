import KiwiDeskCore
import SwiftUI

/// The panel's static key hints for its scope — hidden from
/// VoiceOver, whose row actions say the same (#1875 ▸ footer).
/// Short of room, it sheds hints from the end, the Windows side
/// first collapsing its modifier hints to keycaps (#3249); a hint
/// keeps its index, so the lit one stays lit while it is shown.
struct JumpFooter: View {
    let scope: JumpScope
    /// The modifiers held now, which decide the one lit hint.
    var modifiers: NSEvent.ModifierFlags = []
    /// Whether a row or tile is selected; with none, nothing lights.
    var hasSelection = true
    /// Whether Swap here would trade the selected row, and whether
    /// Move here would take it; a refused one lights nothing under
    /// its modifier (#2885).
    var selectionSwaps = true
    var selectionMoves = true
    /// How many items the View side's ⌘ digits reach on the
    /// selected line (#2309 ruling 7).
    var quickCount = 9
    /// Whether ↩ turns KiwiVision off, which the lit hint then
    /// says instead of Apply (#2103 ruling 56).
    var turnsOff = false
    /// Whether the field names a profile: ↩ saves, Esc goes back,
    /// and no digit picks (#2359).
    var naming = false
    /// The Desktops side's layer, which picks its hints (#1229).
    var desktops: DesktopsFooterState?
    /// Whether the Windows strip has more than one app to step
    /// through (#3159).
    var stripSteps = false
    /// The last-app opener's live chord; nil where it is unbound,
    /// which leaves its hint out (#3159).
    var lastAppChord: String?

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        if let refusal = desktops?.refusal {
            desktopsRefusal(refusal)
        } else if scope == .windows {
            windowsFitted
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            fitted
        }
    }

    private var fitted: some View {
        let hints = hints
        return ViewThatFits(in: .horizontal) {
            // A side's leading hints never shed (#1229 ▸ Footer).
            ForEach((keeps...hints.count).reversed(), id: \.self) {
                row(Array(hints.prefix($0)))
            }
            // Past every candidate the line truncates rather than
            // spill onto the side's controls.
            row([], fixed: false)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// One candidate line of `shown`; a line that is not `fixed`
    /// truncates to the room it is given.
    func row(_ shown: [String], fixed: Bool = true) -> some View {
        HStack(spacing: 8) {
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

    /// How many leading hints never shed: the Desktops side's ↩
    /// pair, or its three carry keys (#1229); every other side
    /// sheds them all.
    var keeps: Int {
        switch scope {
        case .desktops:
            let floor = desktops?.isCarrying == true ? 3 : 2
            return min(floor, hints.count)
        case .windows, .shortcuts, .view:
            return 0
        }
    }
}

extension JumpFooter {
    /// The one hint in full ink: the pick that acts on the
    /// selection with the modifiers held now, read off `JumpKey`
    /// itself — ↩ where it picks, else the ⌘ digits. Navigation and
    /// bridges never light; the Shortcuts side picks nothing (#2246).
    /// The index is into `hints`, whose order it follows: Jump,
    /// Move here, Swap here, the digits on Windows (#3249); Apply,
    /// the digits on View.
    var leading: Int? {
        guard hasSelection, scope != .shortcuts else { return nil }
        if scope == .desktops { return desktopsLeading }
        // ⌃ is left out: the chord that opened the panel may still
        // be held when it draws.
        let held = modifiers.intersection([.shift, .option, .command])
        let one = UInt16(JumpKey.digitRows[0])
        let digit = JumpKey.of(
            keyCode: one,
            modifiers: held,
            scope: scope,
            naming: naming
        )
        // A held chord the digits answer lights them first, though
        // ↩ under it picks as well (#2931 ▸ Ruling 5).
        if case .quickSwap = digit { return 3 }
        if case .quick(_, let moveHere) = digit {
            if scope == .windows { return 3 }
            return moveHere ? nil : 1
        }
        switch JumpKey.of(
            keyCode: JumpKey.returnKey,
            modifiers: held,
            scope: scope,
            naming: naming
        ) {
        // Windows: ↩ Jump, ⇧↩ Move here; View: ↩ Apply.
        case .pick(let moveHere):
            guard scope == .windows else { return moveHere ? nil : 0 }
            guard moveHere else { return 0 }
            return selectionMoves ? 1 : nil
        case .swapHere:
            return selectionSwaps ? 2 : nil
        default:
            return nil
        }
    }

    /// ⇥ and the side it steps to.
    var sideHint: String {
        L(
            "jump.footer.scope",
            "%1$@ %2$@",
            "⇥",
            scope.stepped(forward: true).title
        )
    }

    var hints: [String] {
        let other = sideHint
        switch scope {
        case .desktops:
            return desktopsHints
        case .windows:
            return windowsSlots(held: modifiers).map(\.text)
        case .shortcuts:
            // Edit in Settings… stands beside the hints with its
            // own chord.
            return [other]
        case .view where naming:
            return [
                L("view_picker.footer.save", "%1$@ Save", "↩"),
                L("view_picker.footer.back", "%1$@ Back", "Esc"),
                other,
            ]
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

/// The scope switch at the field's trailing end (#2229): a click
/// target and a mark of where ⇥ goes. The panel reads Tab ahead of
/// every view, so the field keeps the keys. Titles only: a side's
/// live chord stands in for its title while ⌘ is held or the
/// pointer is on it (#1229 ▸ Tab bar, amending #2245).
struct JumpScopeSwitch: View {
    @ObservedObject var model: JumpModel

    var body: some View {
        SegmentedPicker(
            spokenLabel: JumpScope.switchName,
            reservesWeight: true,
            hints: model.chords,
            showsHints: model.commandHeld,
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
