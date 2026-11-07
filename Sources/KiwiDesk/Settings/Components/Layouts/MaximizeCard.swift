import KiwiDeskCore
import SwiftUI

/// Layout Defaults' Maximize card (#3062): the share each
/// directional Maximize takes of its other axis, and where both grow
/// from. Beside the minimum window size, since it applies to every
/// layout; no row ever greys, since the verb reads them from Lua and
/// the CLI whether or not a chord is bound.
struct MaximizeCard: View {
    @ObservedObject var model: SettingsModel

    private var maximize: Binding<MaximizeSettings> {
        $model.config.settings.maximize
    }

    var body: some View {
        SettingsSection(SettingsCatalog.layoutDefaults.maximizeCard) {
            ForEach(LayoutDefaultsRowOrder.maximize, id: \.id) { key in
                row(key)
            }
        }
    }

    @ViewBuilder
    private func row(_ key: SettingKey) -> some View {
        switch key {
        case .behaviour(.maximizeHeightShare):
            RatioRow(
                label: SettingsCatalog.layoutDefaults.maximizeHeightShare.text,
                value: maximize.heightShare,
                range: MaximizeShape.shareRange
            )
            .searchAnchored(SettingsCatalog.layoutDefaults.maximizeHeightShare)
            MaximizeChordCaption(
                model: model,
                command: KeybindingCatalog.maximizeHeight,
                row: SettingsCatalog.shortcuts.maximizeHeightBinding
            )
        case .behaviour(.maximizeWidthShare):
            RatioRow(
                label: SettingsCatalog.layoutDefaults.maximizeWidthShare.text,
                value: maximize.widthShare,
                range: MaximizeShape.shareRange
            )
            .searchAnchored(SettingsCatalog.layoutDefaults.maximizeWidthShare)
            MaximizeChordCaption(
                model: model,
                command: KeybindingCatalog.maximizeWidth,
                row: SettingsCatalog.shortcuts.maximizeWidthBinding
            )
        case .behaviour(.maximizeAnchor):
            SegmentedPicker(
                SettingsCatalog.layoutDefaults.maximizeAnchor.text,
                selection: maximize.anchor,
                options: MaximizeAnchor.allCases.map {
                    (title: Self.anchorName($0), value: $0)
                },
                help: L(
                    "layout_defaults.maximize.anchor.help",
                    "Where a window maximized on one side sits on the "
                        + "other: in the center of the screen, or over "
                        + "its own place in the layout, moved in if it "
                        + "would cross an edge. Maximize itself always "
                        + "fills the screen."
                )
            )
            .searchAnchored(SettingsCatalog.layoutDefaults.maximizeAnchor)
        default:
            let _ = assertionFailure(
                "unrendered Layout Defaults maximize row: \(key.id)"
            )
            EmptyView()
        }
    }

    /// An anchor's name, the picker's and the diff row's.
    static func anchorName(_ anchor: MaximizeAnchor) -> String {
        switch anchor {
        case .center:
            L("layout_defaults.maximize.anchor.center", "Center")
        case .inPlace:
            L("layout_defaults.maximize.anchor.in_place", "Where it is")
        }
    }
}

/// The line under a share row naming the chord that uses it, read
/// from the live binding, and the Shortcuts row it is set in
/// (#3062). A binding passing its own share reads as none, since
/// that chord ignores this setting.
struct MaximizeChordCaption: View {
    @ObservedObject var model: SettingsModel
    let command: NavCommand
    let row: SettingsControl

    var body: some View {
        let chord = ShortcutsOpenBinding.comboGlyphs(
            core: model.core,
            lua: command.lua
        )
        let prose = Self.prose(name: command.displayLabel(), chord: chord)
        CrossReferenceRow(
            prose: prose,
            linkTitle: L(
                "layout_defaults.maximize.xref_link",
                "%1$@ ▸ %2$@",
                SettingsDestination.shortcuts.title,
                SettingsCatalog.shortcuts.sizeFloat.text
            ),
            destination: .shortcuts,
            row: row.id
        )
    }

    /// The sentence for `name`'s live chord, or for none bound.
    static func prose(name: String, chord: String?) -> String {
        guard let chord else {
            return L(
                "layout_defaults.maximize.xref.no_shortcut",
                "%1$@ has no shortcut. Give it one in %2$@.",
                name,
                CrossReferenceRow.linkSlot
            )
        }
        return L(
            "layout_defaults.maximize.xref.shortcut",
            "%1$@ is on %2$@. Change it in %3$@.",
            name,
            chord,
            CrossReferenceRow.linkSlot
        )
    }
}
