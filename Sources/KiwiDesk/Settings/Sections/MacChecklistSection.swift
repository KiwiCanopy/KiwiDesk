import KiwiDeskCore
import SwiftUI

/// The Mac Checklist (#1365): the macOS settings a tiler fights,
/// read live — essentials counted, optionals stated — and the
/// habits no setting can hold. Single column: the card edits no
/// draft, so it offers no panel (`SettingsDetailPanelOffer`). The
/// read itself is the shell's (`SettingsView`), one snapshot for
/// this section and the Home card alike.
struct MacChecklistSection: View {
    @ObservedObject var model: SettingsModel
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                essentials
                optionals
                habits
                GuideLink()
            }
            .padding([.horizontal, .bottom], SettingsMetrics.paneInset)
        }
    }

    private var essentials: some View {
        SettingsSection(
            SettingsCatalog.macChecklist.essentialsCard,
            caption: MacChecklistText.provenance,
            trailing: MacChecklistText.progress(
                done: model.macChecklistDone,
                total: MacChecklistProgress.total
            )
        ) {
            settingRows(MacChecklistRowOrder.essentialSettings)
        }
    }

    private var optionals: some View {
        SettingsSection(SettingsCatalog.macChecklist.optionalCard) {
            settingRows(MacChecklistRowOrder.optionalSettings)
        }
    }

    private var habits: some View {
        // One live-layer read per render, not one per row.
        let panelChord = ShortcutsOpenBinding.comboGlyphs(
            core: model.core
        )
        return SettingsSection(
            SettingsCatalog.macChecklist.habitsCard
        ) {
            ForEach(
                Array(MacChecklistRowOrder.habits.enumerated()),
                id: \.element.id
            ) { index, row in
                if index > 0 { Divider() }
                if case .macChecklist(let key) = row,
                    let control = Self.control(for: key)
                {
                    MacHabitRow(
                        key: key,
                        control: control,
                        panelChord: panelChord
                    )
                }
            }
        }
    }

    private func settingRows(_ rows: [SettingKey]) -> some View {
        let chipWidth = MacSettingRow.chipWidth
        return ForEach(Array(rows.enumerated()), id: \.element.id) {
            index,
            row in
            if index > 0 { Divider() }
            if case .macChecklist(let key) = row,
                let setting = key.setting,
                let control = Self.control(for: key)
            {
                MacSettingRow(
                    model: model,
                    key: key,
                    setting: setting,
                    control: control,
                    chipWidth: chipWidth
                )
            }
        }
    }

    /// The catalog declaration a census row anchors on, keyed on
    /// the row's label key (#1250); nil for the tick store.
    static func control(for key: MacChecklistKey) -> SettingsControl? {
        let catalog = SettingsCatalog.macChecklist
        switch key {
        case .rearrangeSpaces: return catalog.rearrangeSpaces
        case .switchOnActivate: return catalog.switchOnActivate
        case .stageManager: return catalog.stageManager
        case .edgeTiling: return catalog.edgeTiling
        case .clickWallpaper: return catalog.clickWallpaper
        case .doubleClickTitle: return catalog.doubleClickTitle
        case .habitHide: return catalog.habitHide
        case .habitBigWindows: return catalog.habitBigWindows
        case .habitKeyboard: return catalog.habitKeyboard
        case .habitFloat: return catalog.habitFloat
        case .habitDock: return catalog.habitDock
        case .selfTicks: return nil
        }
    }
}
