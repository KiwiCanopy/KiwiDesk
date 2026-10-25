import KiwiDeskCore
import SwiftUI

/// "Shortcuts use: ⌃⌥ | ✦" (#2460), the Modifier keys card's second row
/// in the shortcut rows' shape (`SpaceHistoryRow`): two named peers,
/// neither an "off", in the recorder column. Greyed on `⌃⌥` with its
/// reason while no key is set, since the key field above turns it on
/// (gui.md ▸ Grey, don't hide); live while the base is `✦` with the
/// key cleared, as the way back. Under it, the rows left on `⌃⌥`.
struct ShortcutBaseRow: View {
    @ObservedObject var model: SettingsModel
    /// Why the switch is inert, from the card's gate resolver.
    let reason: ShortcutsGates.InertReason?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                // The icon slot every shortcut row reserves (#264).
                Color.clear.frame(width: Self.iconSlot, height: 1)
                // The picker names itself; this is its drawn twin.
                Text(ShortcutBaseWords.title)
                    .accessibilityHidden(true)
                HelpButton(
                    explanation: ShortcutBaseWords.help,
                    subject: ShortcutBaseWords.title
                )
                Spacer()
                KeyRecorderField.footprint.overlay {
                    picker.modifier(GreyOut(active: greyed, help: captionText))
                }
            }
            // Lua owning the config is the card's caption already.
            if reason != .appWideLuaOwned { caption(captionText) }
            if !left.isEmpty { leftList }
        }
    }

    private static let iconSlot = SettingsMetrics.shortcutIconSlot

    private var keySet: Bool { model.appWide.hyperKey != nil }

    /// No key and nothing on `✦` yet: the switch has nothing to do.
    private var greyed: Bool {
        reason != nil || (!keySet && model.config.shortcutBase == .standard)
    }

    private var picker: some View {
        SegmentedPicker(
            spokenLabel: ShortcutBaseWords.title,
            spokenValue: ShortcutBaseWords.spoken(
                model.config.shortcutBase,
                keySet: keySet
            ),
            spokenTitles: Dictionary(
                uniqueKeysWithValues: ShortcutBase.allCases.map {
                    ($0, ShortcutBaseWords.spoken($0, keySet: keySet))
                }
            ),
            selection: Binding(
                get: { model.config.shortcutBase },
                set: { model.setShortcutBase($0) }
            ),
            options: ShortcutBase.allCases.map {
                (title: ShortcutBaseWords.glyphs($0), value: $0)
            }
        )
    }

    private var captionText: String {
        if reason == .storedProfilePage { return ShortcutBaseWords.storedPage }
        if reason == .appWideLuaOwned {
            return GeneralGateHelp.sentence(for: .luaOwned)
        }
        guard keySet else {
            return model.config.shortcutBase == .hyper
                ? ShortcutBaseWords.keyOff : ShortcutBaseWords.noKey
        }
        return ShortcutBaseWords.caption
    }

    private var left: [ShortcutBaseLeftRow] { model.rowsLeftOnStandard }

    private var leftList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ShortcutBaseWords.leftHeader(left.count))
            ForEach(left) { row in
                Text(ShortcutBaseWords.line(row, config: model.config))
                    .padding(.leading, 12)
            }
        }
        .font(.caption)
        .foregroundStyle(SettingsTheme.ink2)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, Self.iconSlot + 8)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Self.iconSlot + 8)
    }
}
