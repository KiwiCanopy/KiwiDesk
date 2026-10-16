import KiwiDeskCore
import SwiftUI

/// The KiwiVision page (#2103 ▸ the Settings area ruling): the
/// lens strip, then the selected chip's body — Default's
/// four cards, written at once (#1741), or a lens's page, saved
/// with Save (ruling 29). The picture is the side panel's
/// (`KiwiVisionPanelPreview`), following the chip on `nav`.
struct KiwiVisionSection: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                KiwiVisionLensStrip(model: model)
                if let lens = selectedLens {
                    KiwiVisionLensPage(model: model, lens: lens)
                } else {
                    defaultPage
                }
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var selectedLens: VisionLens? {
        let lenses = model.draftLenses
        return model.nav.kiwiVisionLensSelection(in: lenses).flatMap {
            name in lenses.first { $0.name == name }
        }
    }

    /// The Default page: Never dimmed last, every lens's (ruling 47).
    @ViewBuilder private var defaultPage: some View {
        KiwiVisionPointer(model: model)
        KiwiVisionLevelsCard(model: model)
        KiwiVisionClearCard(model: model)
        KiwiVisionAppearanceCard(model: model)
        KiwiVisionNeverDimmedCard(model: model)
    }
}

/// The line naming how KiwiVision turns on: the live chord, the
/// menu-bar row, and the Shortcuts group the chord is set in.
struct KiwiVisionPointer: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        let chord = ShortcutsOpenBinding.comboGlyphs(
            core: model.core,
            lua: KeybindingCatalog.toggleKiwiVision.lua
        )
        CrossReferenceRow(
            prose: Self.prose(chord: chord),
            linkTitle: Self.linkTitle,
            destination: .shortcuts
        )
    }

    /// The sentence for the live chord, or for none bound.
    static func prose(chord: String?) -> String {
        guard let chord else {
            return L(
                "kiwivision.xref.no_shortcut",
                "KiwiVision has no shortcut. Turn it on from the "
                    + "KiwiDesk menu in the menu bar, or give it a "
                    + "shortcut in %1$@.",
                CrossReferenceRow.linkSlot
            )
        }
        return L(
            "kiwivision.xref.shortcut",
            "Turn KiwiVision on and off with %1$@, or from the "
                + "KiwiDesk menu in the menu bar. You can change the "
                + "shortcut in %2$@.",
            chord,
            CrossReferenceRow.linkSlot
        )
    }

    /// Each segment as this locale renders it (localization.md).
    static var linkTitle: String {
        L(
            "kiwivision.xref_link",
            "%1$@ ▸ %2$@",
            SettingsDestination.shortcuts.title,
            SettingsCatalog.shortcuts.focusKeys.text
        )
    }
}
