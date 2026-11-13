import KiwiDeskCore
import SwiftUI

/// The Modifier keys card (#2601 ▸ Ruling 7), above the layer
/// header: it belongs to no layer. Three rows in the shortcut rows'
/// shape: the Hyper key's recorder (#1870), app-wide and written at
/// once like the layout cue (#1741), greyed with its sentence only
/// where `init.lua` owns the config; "Shortcuts use" (#2460),
/// drafted with the layers; and the sides switch (#2601). A
/// collapsible card (#2654) of settings, so shut on arrival with
/// its summary stating what is set, save while Hyper is in trouble
/// (#3261).
struct ModifierKeysCard: View {
    @ObservedObject var model: SettingsModel
    /// The take-over's focus destination (#816): the button leaves
    /// once the remap is KiwiDesk's, and the recorder stays drawn.
    @FocusState private var recorderFocused: Bool
    @State private var expanded = false

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

    /// The one state that opens the card on arrival (#3261): the
    /// remap refused with a Take Over to offer, which must not fold
    /// out of sight. Not a census gate.
    static func opensOnArrival(
        status: HyperKeyStatus,
        luaOwned: Bool
    ) -> Bool {
        takeOverOffer(status: status, luaOwned: luaOwned) != nil
    }

    private var troubled: Bool {
        Self.opensOnArrival(
            status: model.hyperStatus,
            luaOwned: reason == .appWideLuaOwned
        )
    }

    var body: some View {
        SettingsCollapsibleSection(
            SettingsCatalog.shortcuts.modifierKeys,
            isExpanded: $expanded,
            summary: summary(spoken: false),
            spokenSummary: summary(spoken: true)
        ) {
            VStack(alignment: .leading, spacing: 6) {
                keyRow
                    .searchAnchored(
                        SettingsCatalog.shortcuts.modifierKeys.children
                            .hyperKey
                    )
                // The key is app-wide; "Shortcuts use" below it is
                // the draft's (#3218).
                if reason != .appWideLuaOwned {
                    LiveSettingCaption()
                        .padding(
                            .leading,
                            SettingsMetrics.shortcutTextIndent
                        )
                }
                captions
                ShortcutBaseRow(model: model, reason: offerReason)
                    .searchAnchored(
                        SettingsCatalog.shortcuts.modifierKeys.children
                            .shortcutBase
                    )
                    .padding(.top, 6)
                ModifierSidesRow(model: model)
                    .padding(.top, 6)
            }
        }
        // Shut on arrival, save in trouble; never forced shut.
        .onAppear { if troubled { expanded = true } }
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
            HelpButton(
                explanation: HyperKeyWords.help,
                subject: HyperKeyWords.title
            )
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
            .padding(.leading, SettingsMetrics.shortcutTextIndent)
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
            .padding(.leading, SettingsMetrics.shortcutTextIndent)
    }
}
