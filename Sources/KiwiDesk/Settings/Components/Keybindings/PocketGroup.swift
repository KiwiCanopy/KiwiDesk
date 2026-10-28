import KiwiDeskCore
import SwiftUI

/// The Pocket card (#2680): ⌃⌥P and ⌃⌥⇧P, then what the pocket
/// holds (#2678) and where its plate sits. The plate shows on every
/// window drag whatever the animation switch says, so no row greys.
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
            capacityRow
            edgeRow
            positionRow
        }
    }

    private var pocket: Binding<PocketStyle> {
        $model.config.settings.pocketStyle
    }

    /// Two named behaviours, neither an "off", so a pick-one.
    private var capacityRow: some View {
        let label = SettingsCatalog.shortcuts.pocketCapacity.text
        return ShortcutSettingRow(title: label, help: Self.capacityHelp) {
            SegmentedPicker(
                spokenLabel: label,
                spokenValue: Self.capacityName(pocket.wrappedValue.capacity),
                selection: pocket.capacity,
                options: PocketCapacity.allCases.map {
                    (title: Self.capacityName($0), value: $0)
                }
            )
            .fixedSize()
        }
        .searchAnchored(SettingsCatalog.shortcuts.pocketCapacity)
    }

    static func capacityName(_ capacity: PocketCapacity) -> String {
        switch capacity {
        case .one: L("pocket.capacity.one", "One window")
        case .several: L("pocket.capacity.several", "Several windows")
        }
    }

    /// Names both segments through their own keys (#818).
    static var capacityHelp: String {
        L(
            "pocket.capacity.help",
            "%1$@: the Pocket keeps a single window. %2$@: mark more, "
                + "and a plate at the edge holds them; the Pocket key "
                + "takes out the one put in last.",
            capacityName(.one),
            capacityName(.several)
        )
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
                    Text(AppBarOptions.edgeName($0)).tag($0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .neutralMenuLabel()
            .controlSize(.regular)
            .fixedSize()
            .accessibilityLabel(SettingsCatalog.shortcuts.pocketEdge.text)
            .accessibilityValue(
                AppBarOptions.edgeName(pocket.wrappedValue.edge)
            )
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
                    spokenValue: Self.spokenPosition(
                        readout,
                        edge: pocket.wrappedValue.edge
                    ),
                    ends: Self.ends(pocket.wrappedValue.edge)
                )
                Text(readout)
                    .monospacedDigit()
                    .accessibilityHidden(true)
            }
        }
        .searchAnchored(SettingsCatalog.shortcuts.pocketPosition)
    }

    /// The track's ends name where the position runs: left to
    /// right on a top or bottom edge, top to bottom on a side.
    static func ends(_ edge: AppBarEdge) -> (
        leading: String, trailing: String
    ) {
        edge.isHorizontal
            ? ("arrow.left.to.line", "arrow.right.to.line")
            : ("arrow.up.to.line", "arrow.down.to.line")
    }

    /// The position with the end it counts from, one sentence per
    /// orientation so a translator keeps the agreement.
    static func spokenPosition(_ readout: String, edge: AppBarEdge)
        -> String
    {
        edge.isHorizontal
            ? L(
                "pocket.position.spoken.horizontal",
                "%1$@ from the left",
                readout
            )
            : L(
                "pocket.position.spoken.vertical",
                "%1$@ from the top",
                readout
            )
    }

    static var edgeHelp: String {
        L(
            "pocket.edge.help",
            "The screen edge the Pocket plate sits on. A bar on the "
                + "same edge keeps it just inside."
        )
    }

    static var positionHelp: String {
        L(
            "pocket.position.help",
            "Where along its edge the Pocket plate sits, from the "
                + "left or top end to the right or bottom end."
        )
    }
}
