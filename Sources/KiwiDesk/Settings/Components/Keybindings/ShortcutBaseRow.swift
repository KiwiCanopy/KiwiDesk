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
            ShortcutSettingRow(
                title: ShortcutBaseWords.title,
                help: ShortcutBaseWords.help
            ) {
                picker.modifier(GreyOut(active: greyed, help: captionText))
            }
            // Lua owning the config is the card's caption already.
            if reason != .appWideLuaOwned { caption(captionText) }
            if !left.isEmpty { leftList }
        }
    }

    private var keySet: Bool { model.appWide.hyperKey != nil }

    /// No key and nothing on `✦` yet: the switch has nothing to do.
    private var greyed: Bool {
        reason != nil || (!keySet && model.config.shortcutBase == .standard)
    }

    /// Hugs its labels in the footprint (#3262): a hugging strip
    /// still takes a width proposed to it, so it is fixed-size too.
    var picker: some View {
        SegmentedPicker(
            spokenLabel: ShortcutBaseWords.title,
            spokenValue: ShortcutBaseWords.spoken(
                model.config.shortcutBase,
                keySet: keySet
            ),
            hugsLabels: true,
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
        .fixedSize()
    }

    private var captionText: String {
        if reason == .storedProfilePage { return ShortcutBaseWords.storedPage }
        if reason == .appWideLuaOwned {
            return GeneralGateHelp.sentence(for: .luaOwned)
        }
        if keyOff { return ShortcutBaseWords.keyOff }
        return keySet ? ShortcutBaseWords.caption : ShortcutBaseWords.noKey
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
        .padding(.leading, SettingsMetrics.shortcutTextIndent)
    }

    /// The base is ✦ with no key: shortcuts on ✦ are dead, so its
    /// caption is a warning and wears the triangle; `noKey` stays a
    /// plain caption. A gate reason's own caption comes first.
    private var keyOff: Bool {
        reason != .storedProfilePage && reason != .appWideLuaOwned
            && !keySet && model.config.shortcutBase == .hyper
    }

    private func caption(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if keyOff {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(SettingsTheme.warningInk)
                    .accessibilityHidden(true)
            }
            Text(text)
                .foregroundStyle(SettingsTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .padding(.leading, SettingsMetrics.shortcutTextIndent)
    }
}
