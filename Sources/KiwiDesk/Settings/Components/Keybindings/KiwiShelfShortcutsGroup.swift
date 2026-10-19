import KiwiDeskCore
import SwiftUI

/// The bars' show/hide shortcuts (#761), a group of their own as
/// KiwiHub's and KiwiVision's are. A row greys while its bar is
/// `always` everywhere — its shortcut then only refuses — and links
/// to where its bar is set.
struct KiwiShelfShortcutsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.kiwishelfKeys) {
            ForEach(ShortcutsRowOrder.kiwishelfAtRest, id: \.id) {
                key in
                row(key)
            }
        }
    }

    /// The row, and outside its grey the live pointer to where its
    /// bar is set (gui.md ▸ a dim is not a sentence).
    private func row(_ key: SettingKey) -> some View {
        let inert = Self.inert(key, model.config.settings)
        return VStack(alignment: .leading, spacing: 4) {
            KeybindingFamilyRows(
                model: model,
                bindings: $bindings,
                key: key,
                expander: expander
            )
            .modifier(GreyOut(active: inert))
            if inert {
                CrossReferenceRow(
                    prose: Self.caption(key),
                    linkTitle: SettingsDestination.bars.title,
                    destination: .bars
                )
                .font(.caption)
            }
        }
    }

    /// Whether `key`'s bar is `always` in every layout it reaches,
    /// so its shortcut can only refuse — Core's one predicate.
    static func inert(_ key: SettingKey, _ settings: TilingSettings) -> Bool {
        switch key {
        case .shortcuts(.toggleSpaceBar):
            return !settings.revealActionLiveAnywhere(.space)
        case .shortcuts(.toggleAppBar):
            return !settings.revealActionLiveAnywhere(.app)
        default:
            return false
        }
    }

    /// What makes the row's shortcut work, its link at
    /// `CrossReferenceRow.linkSlot` (ui-designer, #761).
    static func caption(_ key: SettingKey) -> String {
        key == .shortcuts(.toggleAppBar)
            ? L(
                "keybinding.toggle_app_bar.inert_link",
                "Works when the App Bar is set to %1$@ or %2$@ for "
                    + "%3$@ or %4$@ in %5$@.",
                L("bar.visibility.auto", "Auto"),
                L("bar.visibility.hidden", "Hidden"),
                L("layout.monocle.name", "Monocle"),
                L("layout.scrolling.name", "Scrolling"),
                CrossReferenceRow.linkSlot
            )
            : L(
                "keybinding.toggle_space_bar.inert_link",
                "Works when the Space Bar is set to %1$@ or %2$@ in "
                    + "%3$@.",
                L("bar.visibility.auto", "Auto"),
                L("bar.visibility.hidden", "Hidden"),
                CrossReferenceRow.linkSlot
            )
    }
}
