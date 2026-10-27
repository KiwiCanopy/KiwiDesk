import KiwiDeskCore
import SwiftUI

/// The Pocket card (#2680): ⌃⌥P and ⌃⌥⇧P, then where the brief
/// pocket appears. The two placement rows grey while "Animate
/// float, Pocket & maximize" is off — the pocket then never
/// appears — with the live pointer to that switch outside the grey
/// (gui.md ▸ a dim is not a sentence).
struct PocketGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.pocketKeys) {
            ForEach(ShortcutsRowOrder.pocketAtRest, id: \.id) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
            // `ShortcutsRowOrder.pocketList`, drawn here.
            Group {
                edgeRow
                positionRow
            }
            .modifier(GreyOut(active: inert))
            if inert {
                CrossReferenceRow(
                    prose: Self.inertProse,
                    linkTitle: L(
                        "shortcuts.pocket.xref_link",
                        "Looks & Animations ▸ Animations"
                    ),
                    destination: .looks
                )
                .font(.caption)
            }
        }
    }

    /// The pocket appears only under the state-change animation.
    private var inert: Bool {
        !model.config.settings.animations.onStateChange
    }

    private var pocket: Binding<PocketStyle> {
        $model.config.settings.pocketStyle
    }

    /// In the shared setting row's shape (#2670), as a menu: the
    /// recorder's footprint has no room for four segments.
    private var edgeRow: some View {
        ShortcutSettingRow(
            title: SettingsCatalog.shortcuts.pocketEdge.text,
            help: Self.edgeHelp
        ) {
            Picker(
                SettingsCatalog.shortcuts.pocketEdge.text,
                selection: pocket.edge
            ) {
                ForEach(AppBarEdge.allCases, id: \.self) {
                    Text(Self.edgeName($0)).tag($0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .neutralMenuLabel()
            .controlSize(.regular)
            .fixedSize()
            .accessibilityLabel(SettingsCatalog.shortcuts.pocketEdge.text)
            .accessibilityValue(Self.edgeName(pocket.wrappedValue.edge))
        }
        .searchAnchored(SettingsCatalog.shortcuts.pocketEdge)
    }

    private var positionRow: some View {
        let label = SettingsCatalog.shortcuts.pocketPosition.text
        let readout = SettingsValueReadout.percent(
            Double(pocket.wrappedValue.position) / 100
        )
        return ShortcutSettingRow(title: label, help: Self.positionHelp) {
            HStack(spacing: 6) {
                SettingsSlider(
                    value: Binding(
                        get: { Double(pocket.wrappedValue.position) },
                        set: { pocket.wrappedValue.position = CGFloat($0) }
                    ),
                    range: 0...100,
                    step: 1,
                    label: label,
                    spokenValue: readout
                )
                Text(readout)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }
        }
        .searchAnchored(SettingsCatalog.shortcuts.pocketPosition)
    }

    static var edgeHelp: String {
        L(
            "pocket.edge.help",
            "The screen edge the Pocket appears on while a window "
                + "goes in or comes out. A bar on the same edge "
                + "keeps it just inside."
        )
    }

    static var positionHelp: String {
        L(
            "pocket.position.help",
            "Where along its edge the Pocket appears, from the "
                + "left or top end to the right or bottom end."
        )
    }

    /// Why the rows are grey, the switch named and its page at
    /// `CrossReferenceRow.linkSlot`.
    static var inertProse: String {
        L(
            "shortcuts.pocket.inert_link",
            "The Pocket appears only while %1$@ is on in %2$@.",
            L(
                "behavior.animations.state_change",
                "Animate float, Pocket & maximize"
            ),
            CrossReferenceRow.linkSlot
        )
    }

    /// An edge's name, as the bars' edge rows say it.
    @MainActor static func edgeName(_ edge: AppBarEdge) -> String {
        AppBarOptions.edge.first { $0.0 == edge }?.1 ?? ""
    }
}
