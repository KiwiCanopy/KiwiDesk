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
    /// The take-over's focus destination (#816): the button leaves
    /// once the remap is KiwiDesk's, and the recorder stays drawn.
    @FocusState private var recorderFocused: Bool

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
                    .padding(.top, 6)
            }
        }
    }

    /// The recorder in the recorder column, ✦ in the icon slot and
    /// the row's drawn label beside it; the record button names
    /// itself.
    private var keyRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ComboSymbols.hyperGlyph)
                .frame(width: SettingsMetrics.shortcutIconSlot)
                .accessibilityHidden(true)
            // The recorder names itself; this is its drawn twin.
            Text(HyperKeyWords.useAs)
                .accessibilityHidden(true)
            Spacer()
            HyperKeyField(
                key: Binding(
                    get: { model.appWide.hyperKey },
                    set: { key in
                        model.setAppWide { $0.hyperKey = key }
                    }
                ),
                disabled: reason == .appWideLuaOwned,
                focus: $recorderFocused
            )
        }
    }

    /// The caption, or — while a leftover remap keeps Hyper off —
    /// the same sentence in a warning box beside its one fix, the
    /// paused banner's shape (owner eyeball, 2026-10-20).
    @ViewBuilder private var captions: some View {
        let text = Self.captionText(
            key: model.appWide.hyperKey,
            status: model.hyperStatus,
            hasShortcuts: model.hyperHasShortcuts,
            luaOwned: reason == .appWideLuaOwned
        )
        if let foreign = Self.takeOverOffer(
            status: model.hyperStatus,
            luaOwned: reason == .appWideLuaOwned
        ) {
            WarningBox(text: text) {
                HyperTakeOverButton(model: model, foreign: foreign) {
                    recorderFocused = true
                }
            }
            .padding(.leading, SettingsMetrics.shortcutIconSlot + 8)
        } else {
            caption(text)
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
        hasShortcuts: Bool,
        luaOwned: Bool
    ) -> String {
        if luaOwned { return GeneralGateHelp.sentence(for: .luaOwned) }
        guard key != nil else { return HyperKeyWords.caption(nil) }
        // The key is chosen but not working: its cost sentence
        // would claim it is Hyper now.
        if let trouble = HyperKeyWords.trouble(status) { return trouble }
        // Chosen, not applied: KiwiDesk is not managing yet.
        if status == .off { return HyperKeyWords.paused }
        // On, but the active layer gives it nothing to do (#2480):
        // Core's live answer, never the draft's rows.
        if let key, !hasShortcuts { return HyperKeyWords.noShortcut(key) }
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
