import KiwiDeskCore
import SwiftUI

/// The Hyper key card (#1870), above the layer header: it belongs
/// to no layer. One recorder row, app-wide and written at once like
/// the layout cue (#1741), greyed with its sentence only where
/// `init.lua` owns the config. Offered in Power User, and in Simple
/// once a key is set or the draft uses Hyper (config presence
/// expands Simple). Below it, the one-shot move offer (#1870).
struct HyperKeyRow: View {
    @ObservedObject var model: SettingsModel
    /// The move sheet, hosted by `ShortcutsSection`, which outlives
    /// this card (`SheetPresentationSeamTests`).
    @Binding var moveRequest: HyperMoveRequest?

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
        ).inertReason(for: .shortcuts(.desktopShortcutBase))
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
                if model.hyperMoveOffer != nil {
                    moveOffer
                }
            }
        }
    }

    /// The one-shot offer: to Hyper while a key is set, back while
    /// none is; it retires once nothing is left to move. Rows are
    /// the draft's, so it greys with them where `init.lua` owns
    /// the config.
    private var moveOffer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(HyperMoveWords.offer(model.hyperMoveDirection)) {
                moveRequest = model.hyperMoveRequest()
            }
            .settingsActionButton()
            .disabled(offerReason != nil)
            if let text = offerCaption { caption(text) }
        }
        .padding(.top, 6)
    }

    /// Why the offer is greyed, or why Hyper rows are dim; nil when
    /// neither. The Lua-owned reason is the card's own caption.
    private var offerCaption: String? {
        guard offerReason != .storedProfilePage else {
            return HyperMoveWords.storedPage
        }
        return model.hyperMoveDirection == .back
            ? HyperMoveWords.offCaption : nil
    }

    private var captions: some View {
        VStack(alignment: .leading, spacing: 4) {
            caption(
                Self.captionText(
                    key: model.appWide.hyperKey,
                    status: model.hyperStatus,
                    luaOwned: reason == .appWideLuaOwned
                )
            )
            if Self.offersRowMoveHint(
                key: model.appWide.hyperKey,
                luaOwned: reason == .appWideLuaOwned
            ) {
                caption(HyperKeyWords.rowMoveHint)
            }
        }
    }

    /// Whether the caption also points at a row's Move to Hyper:
    /// only while a key is set, since the row action needs one.
    static func offersRowMoveHint(
        key: HyperSourceKey?,
        luaOwned: Bool
    ) -> Bool {
        key != nil && !luaOwned
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
    }
}
