import KiwiDeskCore
import SwiftUI

/// Layout Defaults' Maximize card (#3062, amendment 2026-11-08): for
/// each shape of screen, the share each directional Maximize takes
/// of its other axis and where it grows from. The shapes of the
/// connected screens show; the rest wait in a drawer. Nothing greys:
/// the verb reads every row from Lua and the CLI too.
struct MaximizeCard: View {
    @ObservedObject var model: SettingsModel

    private var controls: LayoutDefaultsControls {
        SettingsCatalog.layoutDefaults
    }

    /// The connected screens, by shape.
    private var screens: [ScreenShape: [Display]] {
        Dictionary(grouping: model.displays) {
            ScreenShape(ScreenClass.of($0))
        }
    }

    private var shown: [ScreenShape] {
        ScreenShape.allCases.filter { screens[$0] != nil }
    }

    private var hidden: [ScreenShape] {
        ScreenShape.allCases.filter { screens[$0] == nil }
    }

    var body: some View {
        SettingsSection(
            controls.maximizeCard,
            caption: L(
                "layout_defaults.maximize.caption",
                "How wide %1$@ makes a window, and how tall %2$@ "
                    + "makes it, for each shape of screen. A screen's "
                    + "shape comes from its size.",
                KeybindingCatalog.maximizeHeight.displayLabel(),
                KeybindingCatalog.maximizeWidth.displayLabel()
            ),
            help: MaximizeShapeText.thresholds
        ) {
            VStack(alignment: .leading, spacing: 8) {
                header
                ForEach(shown, id: \.self) { shape in
                    MaximizeShapeRow(
                        model: model,
                        shape: shape,
                        screens: screens[shape] ?? []
                    )
                }
            }
            if !hidden.isEmpty {
                SettingsDisclosure(
                    controls.maximizeOtherShapes,
                    summary: hidden.map(MaximizeShapeText.name)
                        .joined(separator: ", ")
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(hidden, id: \.self) { shape in
                            MaximizeShapeRow(
                                model: model,
                                shape: shape,
                                screens: []
                            )
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                MaximizeChordCaption(
                    model: model,
                    command: KeybindingCatalog.maximizeHeight,
                    row: SettingsCatalog.shortcuts.maximizeHeightBinding
                )
                MaximizeChordCaption(
                    model: model,
                    command: KeybindingCatalog.maximizeWidth,
                    row: SettingsCatalog.shortcuts.maximizeWidthBinding
                )
            }
        }
    }

    /// The column headings, one per census key in the card's order.
    private var header: some View {
        HStack(alignment: .bottom, spacing: MaximizeShapeRow.spacing) {
            Text(
                L("layout_defaults.maximize.screen_shape", "Screen shape")
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(LayoutDefaultsRowOrder.maximize, id: \.id) { key in
                Text(Self.heading(key))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(
                        width: MaximizeShapeRow.columnWidth,
                        alignment: .leading
                    )
                    .searchAnchored(Self.control(key))
            }
        }
        .font(.callout)
        .foregroundStyle(SettingsTheme.ink2)
        .accessibilityHidden(true)
    }

    /// A column's catalog anchor.
    static func control(_ key: SettingKey) -> SettingsControl {
        switch key {
        case .behaviour(.maximizeHeightShare):
            SettingsCatalog.layoutDefaults.maximizeHeightShare
        case .behaviour(.maximizeWidthShare):
            SettingsCatalog.layoutDefaults.maximizeWidthShare
        default:
            SettingsCatalog.layoutDefaults.maximizeAnchor
        }
    }

    /// A column's heading: the share columns' labels, and "From".
    static func heading(_ key: SettingKey) -> String {
        switch key {
        case .behaviour(.maximizeHeightShare),
            .behaviour(.maximizeWidthShare):
            control(key).text
        default:
            L("layout_defaults.maximize.from", "From")
        }
    }

    /// An anchor's name, the pop-up's and the diff row's.
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
            row: row
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
