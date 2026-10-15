import KiwiDeskCore
import SwiftUI

/// The Hyper key card (#1870), above the layer header: it belongs
/// to no layer. One recorder row, app-wide and written at once like
/// the layout cue (#1741), greyed with its sentence only where
/// `init.lua` owns the config. Offered in Power User, and in Simple
/// once a key is set (config presence expands Simple).
struct HyperKeyRow: View {
    @ObservedObject var model: SettingsModel

    /// The one offer predicate, evaluated at `.simple` for the
    /// mode-gated frame (#760).
    static func isOffered(
        in mode: SettingsMode,
        key: HyperSourceKey?
    ) -> Bool {
        mode == .powerUser || key != nil
    }

    private var reason: ShortcutsGates.InertReason? {
        ShortcutsGates(config: model.config, guiManaged: model.guiManaged)
            .inertReason(for: .shortcuts(.hyperKey))
    }

    var body: some View {
        if Self.isOffered(
            in: model.settingsMode,
            key: model.appWide.hyperKey
        ) {
            card
        }
    }

    private var card: some View {
        SettingsSection(
            SettingsCatalog.shortcuts.hyperKey,
            help: HyperKeyWords.help,
            modeGated: !Self.isOffered(
                in: .simple,
                key: model.appWide.hyperKey
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HyperKeyField(
                    key: Binding(
                        get: { model.appWide.hyperKey },
                        set: { key in
                            model.setAppWide { $0.hyperKey = key }
                        }
                    ),
                    disabled: reason == .appWideLuaOwned
                )
                captions
            }
        }
    }

    @ViewBuilder private var captions: some View {
        if reason == .appWideLuaOwned {
            caption(GeneralGateHelp.sentence(for: .luaOwned))
        } else if model.appWide.hyperKey != nil,
            let trouble = HyperKeyWords.trouble(model.hyperStatus)
        {
            // The key is chosen but not working: its cost sentence
            // would claim it is Hyper now.
            caption(trouble)
        } else if model.appWide.hyperKey != nil,
            model.hyperStatus == .off
        {
            // Chosen, not applied: KiwiDesk is not managing yet.
            caption(HyperKeyWords.paused)
        } else {
            caption(HyperKeyWords.caption(model.appWide.hyperKey))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
