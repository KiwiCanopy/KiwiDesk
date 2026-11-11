import KiwiDeskCore
import SwiftUI

/// The edited layer's key sequences (#1871 ▸ Settings), a
/// collapsible card under Layers: each sequence an outline from its
/// leader, recorded with the shortcut recorder. Shut with a summary
/// until a sequence exists, then open on arrival, as Layers is
/// (#2654); it is never swapped for another container, so a
/// recorder inside survives its first combo (#1125).
struct KeySequencesCard: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows
    @State private var expanded = false
    @State private var collapsed: Set<UUID> = []
    @State private var fresh: UUID?

    private var sequences: [KeyBinding] { bindings.filter(\.isSequence) }

    var body: some View {
        let catalog = SequenceActionCatalog(expander: expander)
        return SettingsCollapsibleSection(
            SettingsCatalog.shortcuts.keySequencesCard,
            isExpanded: $expanded,
            summary: summary(catalog),
            help: Self.help
        ) {
            VStack(alignment: .leading, spacing: 12) {
                rows(catalog)
            }
        }
        // Open on arrival once in use — never forced shut.
        .onAppear { if !sequences.isEmpty { expanded = true } }
        // A layer picked that holds sequences opens it too.
        .onChange(of: sequences.isEmpty) { _, empty in
            if !empty { expanded = true }
        }
    }

    @ViewBuilder private func rows(
        _ catalog: SequenceActionCatalog
    ) -> some View {
        ForEach(sequences) { sequence in
            SequenceNodeRow(
                model: model,
                editing: SequenceEditing(
                    bindings: $bindings,
                    rootID: sequence.id
                ),
                node: sequence,
                catalog: catalog,
                collapsed: $collapsed,
                fresh: $fresh
            )
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

    /// The sequences by name once one exists, or what one is.
    private func summary(_ catalog: SequenceActionCatalog) -> String {
        guard !sequences.isEmpty else {
            return L(
                "shortcuts.sequence.summary",
                "Press a key, then more keys"
            )
        }
        return LocalizedList.join(
            sequences.map {
                SequenceNames.name(
                    of: $0,
                    catalog: catalog,
                    config: model.config
                )
            }
        )
    }
}
