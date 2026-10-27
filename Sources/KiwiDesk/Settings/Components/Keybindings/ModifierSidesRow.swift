import KiwiDeskCore
import SwiftUI

/// "Tell left and right modifiers apart" (#2601), the Modifier keys
/// card's third row: a checkbox in the shortcut rows' icon slot,
/// app-wide and written at once like the layout cue (#1741), greyed
/// only where `init.lua` owns the config — the card's caption says
/// so already. The `?` carries the privacy line; a caption shows
/// only a live fact (#2601 ▸ Ruling 2).
struct ModifierSidesRow: View {
    @ObservedObject var model: SettingsModel

    private var reason: ShortcutsGates.InertReason? {
        ShortcutsGates(config: model.config, guiManaged: model.guiManaged)
            .inertReason(for: .shortcuts(.modifierSides))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ToggleRow(
                label: ModifierSidesWords.title,
                isOn: Binding(
                    get: { model.appWide.modifierSides },
                    set: { on in model.setAppWide { $0.modifierSides = on } }
                ),
                help: ModifierSidesWords.help,
                disabled: reason == .appWideLuaOwned
            )
            .searchAnchored(
                SettingsCatalog.shortcuts.modifierKeys.children.modifierSides
            )
            if let text = captionText { caption(text) }
        }
        .padding(.leading, SettingsMetrics.shortcutIconSlot + 8)
    }

    private var captionText: String? {
        guard reason != .appWideLuaOwned else { return nil }
        return Self.captionText(
            on: model.appWide.modifierSides,
            status: model.sideTapStatus,
            sided: model.sidedShortcutCount
        )
    }

    /// The live fact under the switch, nil while there is none.
    static func captionText(
        on: Bool,
        status: SideTapStatus,
        sided: Int
    ) -> String? {
        if on { return status == .refused ? ModifierSidesWords.refused : nil }
        return sided > 0 ? ModifierSidesWords.waiting(sided) : nil
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(SettingsTheme.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, ToggleRow.captionIndent)
    }
}

/// The sides switch's words (#2601): Core names the tap's state,
/// the GUI writes the sentence (#96).
@MainActor
enum ModifierSidesWords {
    static var title: String {
        SettingsCatalog.shortcuts.modifierKeys.children.modifierSides.text
    }

    static var help: String {
        L(
            "shortcuts.modifier_sides.help",
            "When this is on, a shortcut you record keeps the side you "
                + "pressed: %1$@ with H is recorded as %2$@, so it and "
                + "%3$@ can do different things. Shortcuts recorded "
                + "earlier still work from either side. While this is "
                + "on, every new recording keeps its side; for one that "
                + "works from either side, record it with this off or "
                + "write %4$@ in Lua. To tell the sides apart, KiwiDesk "
                + "reads key presses, but only while at least one "
                + "shortcut keeps a side, and it acts only on the "
                + "shortcuts on those keys.",
            HyperKeyWords.name(.rightCommand),
            drawn(.right) + "H",
            drawn(.left) + "H",
            "cmd+h"
        )
    }

    /// A sided ⌘ as every surface draws it (`ComboSymbols`), `R⌘`;
    /// the example's key stays the frame's own H, whatever the
    /// keyboard layout draws for it.
    static func drawn(_ side: ModifierSide) -> String {
        ComboSymbols.modifierSymbols(
            HotkeyModifiers.command.union(.side(side, of: .command))
        )
    }

    /// Off, with shortcuts that keep a side: they fire either-side.
    /// The count ends its own line (localization.md ▸ a COUNT).
    static func waiting(_ count: Int) -> String {
        L(
            "shortcuts.modifier_sides.waiting",
            "Shortcuts keeping a side: %1$d",
            count
        )
            + "\n"
            + L(
                "shortcuts.modifier_sides.waiting_detail",
                "They work from either side until this is on."
            )
    }

    /// On, but macOS refused the tap: the sided shortcuts fall back
    /// to either side until KiwiDesk asks again.
    static var refused: String {
        L(
            "shortcuts.modifier_sides.refused",
            "macOS refused to let KiwiDesk read key presses, so "
                + "shortcuts keeping a side work from either side for "
                + "now. KiwiDesk asks again when it next starts "
                + "managing your windows."
        )
    }

    /// A sided row's hint while the switch is off (#2601 ▸ Ruling).
    static var eitherSideHint: String {
        L(
            "shortcuts.modifier_sides.either_side_hint",
            "Works from either side while %1$@ is off.",
            title
        )
    }
}
