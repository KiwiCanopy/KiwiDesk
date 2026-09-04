import KiwiDeskCore
import SwiftUI

/// The Desktop families in a shortcut group: at rest once one is
/// bound, behind their own offer until then (#1125).
///
/// A Desktop is macOS's arrangement rather than KiwiDesk's, the
/// seed authors none of these, and they scale per Desktop — so a
/// fresh install met a dozen rows for a concept the app has not
/// introduced. The offer is the door: withholding them outright
/// would leave no way in, their labels being dynamic and so
/// unreachable by search.
struct DesktopShortcutsOffer: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    /// The families to draw, the interleaved follower included.
    let keys: [SettingKey]
    let drawer: SettingsDrawer<SettingsNoChildren>
    let expander: ShortcutsFamilyRows
    @State private var expanded = false

    /// Whether the families draw at rest, asked of the resolver
    /// rather than re-derived here (`ShortcutsGates`).
    private var bound: Bool {
        keys.first.map {
            ShortcutsGates(config: model.config)
                .inertReason(for: $0) == nil
        } ?? false
    }

    /// Whether there is anything to draw at all: with no bridge
    /// and nothing bound the families expand to nothing, and an
    /// offer opening on an empty drawer is worse than no offer.
    private var hasRows: Bool {
        keys.contains { !expander.renderedRows(for: $0).isEmpty }
    }

    @ViewBuilder var body: some View {
        if hasRows {
            if bound {
                families
            } else {
                SettingsDisclosure(
                    drawer,
                    isExpanded: $expanded
                ) {
                    families
                }
            }
        }
    }

    @ViewBuilder private var families: some View {
        ForEach(keys, id: \.id) { key in
            KeybindingFamilyRows(
                model: model,
                bindings: $bindings,
                key: key,
                expander: expander
            )
        }
    }
}
