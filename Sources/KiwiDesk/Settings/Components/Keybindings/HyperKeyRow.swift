import KiwiDeskCore
import SwiftUI

/// The Hyper key card (#1870), above the layer header: it belongs
/// to no layer. Two rows in the shortcut rows' shape: the key's
/// recorder, app-wide and written at once like the layout cue
/// (#1741), greyed with its sentence only where `init.lua` owns the
/// config; and "Shortcuts use" (#2460), drafted with the layers.
/// Offered in Power User, and in Simple once a key is set or the
/// draft uses Hyper (config presence expands Simple).
struct HyperKeyRow: View {
    @ObservedObject var model: SettingsModel

    /// The one offer predicate, evaluated at `.simple` for the
    /// mode-gated frame (#760).
    static func isOffered(
        in mode: SettingsMode,
        key: HyperSourceKey?,
        usesHyper: Bool = false
    ) -> Bool {
        mode == .powerUser || key != nil || usesHyper
    }

    private var reason: ShortcutsGates.InertReason? {
        ShortcutsGates(config: model.config, guiManaged: model.guiManaged)
            .inertReason(for: .shortcuts(.hyperKey))
    }

    private var offerReason: ShortcutsGates.InertReason? {
        ShortcutsGates(
            config: model.config,
            guiManaged: model.guiManaged,
            editingStoredProfile: model.editingStoredProfile
        ).inertReason(for: .shortcuts(.shortcutBase))
    }

    var body: some View {
        if Self.isOffered(
            in: model.settingsMode,
            key: model.appWide.hyperKey,
            usesHyper: model.draftUsesHyper
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
                key: model.appWide.hyperKey,
                usesHyper: model.draftUsesHyper
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                keyRow
                captions
                ShortcutBaseRow(model: model, reason: offerReason)
                    .padding(.top, 4)
            }
        }
    }

    /// The recorder in the recorder column, ✦ in the icon slot; the
    /// card's header is the row's label, and the record button names
    /// itself with it.
    private var keyRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ComboSymbols.hyperGlyph)
                .frame(width: SettingsMetrics.shortcutIconSlot)
                .accessibilityHidden(true)
            Spacer()
            HyperKeyField(
                key: Binding(
                    get: { model.appWide.hyperKey },
                    set: { key in
                        model.setAppWide { $0.hyperKey = key }
                    }
                ),
                disabled: reason == .appWideLuaOwned
            )
        }
    }

    private var captions: some View {
        VStack(alignment: .leading, spacing: 6) {
            caption(
                Self.captionText(
                    key: model.appWide.hyperKey,
                    status: model.hyperStatus,
                    luaOwned: reason == .appWideLuaOwned
                )
            )
            if let foreign = Self.takeOverOffer(
                status: model.hyperStatus,
                luaOwned: reason == .appWideLuaOwned
            ) {
                HyperTakeOverButton(model: model, foreign: foreign)
            }
        }
    }

    /// The remap the row offers to take over: Core's `claimable`
    /// verdict, never a key comparison here (#2471).
    static func takeOverOffer(
        status: HyperKeyStatus,
        luaOwned: Bool
    ) -> HyperForeignRemap? {
        guard !luaOwned, case .refused(let foreign?) = status,
            foreign.claimable
        else { return nil }
        return foreign
    }

    /// The one sentence under the field.
    static func captionText(
        key: HyperSourceKey?,
        status: HyperKeyStatus,
        luaOwned: Bool
    ) -> String {
        if luaOwned { return GeneralGateHelp.sentence(for: .luaOwned) }
        guard key != nil else { return HyperKeyWords.caption(nil) }
        // The key is chosen but not working: its cost sentence
        // would claim it is Hyper now.
        if let trouble = HyperKeyWords.trouble(status) { return trouble }
        // Chosen, not applied: KiwiDesk is not managing yet.
        if status == .off { return HyperKeyWords.paused }
        return HyperKeyWords.caption(key)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, SettingsMetrics.shortcutIconSlot + 8)
    }
}
