import KiwiDeskCore
import SwiftUI

/// A sequence node's recorder (#1871 ▸ Conflicts): a leader is
/// judged against its layer's rows, a step key against the other
/// keys of its step.
extension SequenceNodeRow {
    /// The node's name field and action pop-up as VoiceOver names
    /// them: by the node's chord, or as the new key.
    var nameLabel: String {
        guard !node.combo.isEmpty else {
            return L("shortcuts.sequence.name_ax_new", "Name for the new key")
        }
        return L("shortcuts.sequence.name_ax", "Name for %1$@", chordWords)
    }

    var actionLabel: String {
        guard !node.combo.isEmpty else {
            return L(
                "shortcuts.sequence.action_ax_new",
                "Action for the new key"
            )
        }
        return L("shortcuts.sequence.action_ax", "Action for %1$@", chordWords)
    }

    var chordWords: String {
        SidedChordWords.label(KeySequenceHint.drawn(node.combo))
    }

    var recorder: some View {
        KeyRecorderField(
            name: name,
            combo: node.combo,
            reading: reading,
            preflight: preflight,
            onRecord: record,
            onClear: { editing.update(node.id) { $0.combo = "" } },
            armsOnAppear: fresh == node.id
        )
    }

    /// A leader is judged against the layer's rows; a step key
    /// against its step's other keys (#1871 ▸ Conflicts).
    var reading: ConflictReading? {
        if let refused = refusal { return refused }
        if isLeader {
            return ConflictText.reading(
                for: node,
                in: editing.rows,
                config: model.config,
                disabled: disabledSystemShortcuts,
                sides: model.appWide.modifierSides
            )
        }
        guard let root = editing.root,
            let holder = SequenceTree.sibling(
                holding: node.combo,
                besides: node.id,
                in: root
            )
        else { return nil }
        return ConflictReading(
            severity: .duplicate(holder),
            sentence: L(
                "keybinding.conflict.tooltip.in_step",
                "Also bound at this point in the sequence to %1$@ — only "
                    + "one of the two will fire.",
                holderName(holder)
            )
        )
    }

    /// A chord the router never matches here (Core's
    /// `KeyBinding.admitsStepKey` / `admitsLeader`): it is kept and
    /// flagged, as the engine files it.
    var refusal: ConflictReading? {
        guard !node.combo.isEmpty else { return nil }
        if isLeader {
            guard !KeyBinding.admitsLeader(node.combo) else { return nil }
            return ConflictReading(
                severity: .unrecognized,
                sentence: L(
                    "keybinding.conflict.tooltip.not_leader",
                    "A Hyper chord can't start a key sequence."
                )
            )
        }
        guard let leader = editing.root?.combo,
            !KeyBinding.admitsStepKey(node.combo, under: leader)
        else { return nil }
        return ConflictReading(
            severity: .unrecognized,
            sentence: L(
                "keybinding.conflict.tooltip.not_step",
                "Can't be a key in a sequence: a modifier tapped alone, "
                    + "a Hyper chord, the sequence's first key, or esc "
                    + "or ⌫ on its own."
            )
        )
    }

    func preflight(_ combo: String) -> RecorderRejection? {
        if isLeader {
            return RecorderPreflight.rejection(
                combo: combo,
                excluding: { [id = node.id] in $0.id == id },
                bindings: editing.bindings,
                config: model.config,
                commit: record
            )
        }
        guard let root = editing.root,
            let holder = SequenceTree.sibling(
                holding: combo,
                besides: node.id,
                in: root
            )
        else { return nil }
        return RecorderRejection(
            combo: combo,
            holder: holderName(holder),
            holderRowID: holder.id.uuidString,
            steal: { [editing, armed = $fresh, id = node.id] in
                armed.wrappedValue = nil
                editing.update(holder.id) { $0.combo = "" }
                editing.update(id) { $0.combo = combo }
            },
            inStep: true
        )
    }

    func holderName(_ holder: KeyBinding) -> String {
        SequenceNames.name(of: holder, catalog: catalog, config: model.config)
    }

    func record(_ combo: String) {
        if isLeader {
            model.carrySequenceReach(
                layer: layerName,
                from: node.combo,
                to: combo
            )
        }
        editing.update(node.id) { $0.combo = combo }
        if fresh == node.id { fresh = nil }
        if isLeader, let root = editing.root {
            model.noteRecordedCombo(root, in: editing.rows)
        }
    }
}
