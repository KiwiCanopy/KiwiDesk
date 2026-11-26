import KiwiDeskCore
import SwiftUI

/// The panel's static key hints for its scope — hidden from
/// VoiceOver, whose row actions say the same (#1875 ▸ footer).
/// Short of room, it sheds hints from the end, the Windows side
/// first collapsing its modifier hints to keycaps (#3249); a hint
/// keeps its index, so a lit one stays lit while it is shown.
struct JumpFooter: View {
    let scope: JumpScope
    /// The modifiers held now, which decide the lit hints.
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
    /// The last-app opener as bound; nil where it is unbound, which
    /// leaves its hint out (#3159). Its ⇧ form steps the strip back
    /// (#3135).
    var lastAppCombo: KeyCombo?

    @Environment(\.kiwiDeskReduceMotion) var reduceMotion

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
                stable($0)
            }
            // Past every candidate the line truncates rather than
            // spill onto the side's controls.
            row([], fixed: false)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    /// The first `shown` hints as wide as under any held chord, so
    /// a press re-words the line and never sheds the hint it lights
    /// (#3667, as #3249 fits the Windows line).
    private func stable(_ shown: Int) -> some View {
        ZStack {
            ForEach(Self.heldStates, id: \.rawValue) { held in
                let footer = holding(held)
                footer.row(Array(footer.hints.prefix(shown))).hidden()
            }
            row(Array(hints.prefix(shown)))
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// This footer under `held`.
    func holding(_ held: NSEvent.ModifierFlags) -> JumpFooter {
        var footer = self
        footer.modifiers = held
        return footer
    }

    /// One candidate line of `shown`; a line that is not `fixed`
    /// truncates to the room it is given.
    func row(_ shown: [String], fixed: Bool = true) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, hint in
                if index > 0 { Text(verbatim: "·") }
                Text(hint)
                    .foregroundStyle(
                        lit.contains(index)
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
    /// The hints in full ink, as indices into `hints` (#2246, as
    /// amended by #3667): every press that acts now, read off
    /// `JumpKey` — the pick and the chords the held keys complete,
    /// which need a selection, and the side switch, last, wherever
    /// Tab steps a side. Bare navigation never lights.
    var lit: Set<Int> {
        var lit: Set<Int> = []
        if hasSelection {
            switch scope {
            case .desktops: lit = desktopsLit
            case .windows: lit = Set([windowsLeading].compactMap { $0 })
            case .view: lit = Set([viewPick].compactMap { $0 })
            case .shortcuts: break
            }
        }
        if scope == .windows { lit.formUnion(windowsOpenerLit) }
        let count = hints.count
        if count > 0, tabSteps(modifiers) { lit.insert(count - 1) }
        return lit
    }

    /// The held keys a hint reads: ⌃ is left out, since the chord
    /// that opened the panel may still be held when it draws.
    static func held(
        _ modifiers: NSEvent.ModifierFlags
    ) -> NSEvent.ModifierFlags {
        modifiers.intersection([.shift, .option, .command])
    }

    /// What Tab does under `held`: step a side, forward or back,
    /// or nothing (nil), as the panel itself reads it.
    func tabStep(_ held: NSEvent.ModifierFlags) -> Bool? {
        let key = JumpKey.of(
            keyCode: JumpKey.tab,
            modifiers: Self.held(held),
            scope: scope,
            naming: naming
        )
        if case .stepScope(let forward) = key { return forward }
        return nil
    }

    /// Whether Tab under `held` steps a side.
    func tabSteps(_ held: NSEvent.ModifierFlags) -> Bool {
        tabStep(held) != nil
    }

    /// The View side's pick: ↩ Apply, else its ⌘ digits.
    private var viewPick: Int? {
        let held = Self.held(modifiers)
        let one = UInt16(JumpKey.digitRows[0])
        if case .quick(_, let moveHere) = JumpKey.of(
            keyCode: one,
            modifiers: held,
            scope: scope,
            naming: naming
        ) {
            return moveHere ? nil : 1
        }
        // View: ↩ Apply.
        switch JumpKey.of(
            keyCode: JumpKey.returnKey,
            modifiers: held,
            scope: scope,
            naming: naming
        ) {
        case .pick(let moveHere): return moveHere ? nil : 0
        default: return nil
        }
    }

    /// The side switch worded for `held`: ⇥ and the next side, or
    /// ⇧⇥ and the previous one where ⇧ makes Tab step back.
    func sideHint(_ held: NSEvent.ModifierFlags) -> String {
        let back = tabStep(held) == false
        return L(
            "jump.footer.scope",
            "%1$@ %2$@",
            back ? "⇧⇥" : "⇥",
            scope.stepped(forward: !back).title
        )
    }

    var hints: [String] {
        let other = sideHint(modifiers)
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
