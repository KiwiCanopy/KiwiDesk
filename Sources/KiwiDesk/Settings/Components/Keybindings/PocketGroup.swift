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
            // What it holds leads its keys (owner, #2678).
            capacityRow
            ForEach(ShortcutsRowOrder.pocketAtRest, id: \.id) { key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
            }
        }
    }

    /// A menu like Edge's: the recorder's footprint has no room for
    /// two spelled-out segments.
    private var capacityRow: some View {
        let label = SettingsCatalog.shortcuts.pocketCapacity.text
        return ShortcutSettingRow(title: label, help: Self.capacityHelp) {
            // App-wide, written at once (#1741).
            Picker(
                label,
                selection: Binding(
                    get: { model.appWide.pocketCapacity },
                    set: { new in
                        model.setAppWide { $0.pocketCapacity = new }
                    }
                )
            ) {
                ForEach(PocketCapacity.allCases, id: \.self) {
                    Text(Self.capacityName($0)).tag($0)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .neutralMenuLabel()
            .controlSize(.regular)
            .fixedSize()
            .accessibilityLabel(label)
            .accessibilityValue(
                Self.capacityName(model.appWide.pocketCapacity)
            )
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
                + "and the Pocket stays on screen on every display; the "
                + "Pocket key puts away the one you used, or with all "
                + "inside takes out the one put in last. Applies at "
                + "once, in every profile.",
            capacityName(.one),
            capacityName(.several)
        )
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
}
