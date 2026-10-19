import KiwiDeskCore
import SwiftUI

/// The bars' show/hide shortcuts (#761), a group of their own as
/// KiwiHub's and KiwiVision's are. A row greys while its bar is
/// `always` everywhere — its shortcut then only refuses — and says
/// what makes it work.
struct KiwiShelfShortcutsGroup: View {
    @ObservedObject var model: SettingsModel
    @Binding var bindings: [KeyBinding]
    let expander: ShortcutsFamilyRows

    var body: some View {
        SettingsSection(SettingsCatalog.shortcuts.kiwishelfKeys) {
            ForEach(ShortcutsRowOrder.kiwishelfAtRest, id: \.id) {
                key in
                KeybindingFamilyRows(
                    model: model,
                    bindings: $bindings,
                    key: key,
                    expander: expander
                )
                .modifier(
                    GreyOut(
                        active: Self.inert(key, model.config.settings),
                        help: Self.caption(key)
                    )
                )
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

    /// What makes the row's shortcut work (ui-designer, #761).
    static func caption(_ key: SettingKey) -> String {
        key == .shortcuts(.toggleAppBar)
            ? L(
                "keybinding.toggle_app_bar.inert",
                "Works when the App Bar is set to %1$@ or %2$@ in "
                    + "%3$@ or %4$@.",
                L("bar.visibility.auto", "Auto"),
                L("bar.visibility.hidden", "Hidden"),
                L("layout.monocle.name", "Monocle"),
                L("layout.scrolling.name", "Scrolling")
            )
            : L(
                "keybinding.toggle_space_bar.inert",
                "Works when the Space Bar is set to %1$@ or %2$@.",
                L("bar.visibility.auto", "Auto"),
                L("bar.visibility.hidden", "Hidden")
            )
    }
}
