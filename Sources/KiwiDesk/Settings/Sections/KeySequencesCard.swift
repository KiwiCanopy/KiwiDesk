import KiwiDeskCore
import SwiftUI

/// The edited layer's key sequences (#1871 ▸ Settings), an open
/// card on Personal, which draws its offers open
/// (`docs/design-decisions.md` ▸ One page, three parts): each
/// sequence an outline from its leader, recorded with the shortcut
/// recorder.
struct KeySequencesCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows
    @State private var collapsed: Set<UUID> = []
    @State private var fresh: UUID?

    private var sequences: [KeyBinding] { bindings.filter(\.isSequence) }

    var body: some View {
        let catalog = SequenceActionCatalog(expander: expander)
        return SettingsSection(
            SettingsCatalog.shortcuts.keySequencesCard.control,
            help: Self.help
        ) {
            VStack(alignment: .leading, spacing: 12) {
                rows(catalog)
            }
        }
    }

    @ViewBuilder private func rows(
        _ catalog: SequenceActionCatalog
    ) -> some View {
        // A rule between two sequences, none above Add Sequence
        // (#3425).
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sequences.enumerated()), id: \.element.id) {
                index,
                sequence in
                if index > 0 {
                    SettingsTheme.hairlineSubtle
                        .frame(height: 1)
                        .padding(.vertical, 10)
                        .accessibilityHidden(true)
                }
                SequenceNodeRow(
                    model: model,
                    editing: SequenceEditing(
                        bindings: $bindings,
                        rootID: sequence.id
                    ),
                    node: sequence,
                    path: [sequence.combo],
                    catalog: catalog,
                    collapsed: $collapsed,
                    fresh: $fresh
                )
            }
        }
        Button(action: add) {
            Label(
                L("shortcuts.sequence.add", "Add Sequence"),
                systemImage: "plus"
            )
        }
        .settingsActionButton()
    }

    /// The concept, in the title's `?` (#3162 ▸ second amendment).
    static var help: String {
        L(
            "shortcuts.sequence.caption",
            "Also known as a leader key. Press the first chord (the "
                + "leader) and a panel lists the next keys. A key can "
                + "open more keys; the last key runs its action. esc "
                + "cancels, ⌫ goes back one step."
        )
    }

    private func add() {
        let leader = KeyBinding.sequence(combo: "")
        bindings.append(leader)
        fresh = leader.id
    }
}
