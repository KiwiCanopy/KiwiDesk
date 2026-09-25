import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A label that names a layout does so by that layout's own key
/// (#818, Family B), and every surface reading it — the control,
/// search, the unsaved-changes list — renders the name, never a
/// bare specifier (#1517).
@Suite("Layout-naming labels")
@MainActor
struct ShelfShowLabelTests {
    @Test("the census label and the control read one sentence")
    func labelsNameTheirLayout() {
        LocalizationManager.shared.select("en")
        let monocle = SettingsCensusLabel.label(
            for: .layoutAppBar(.monocleAppBarEnabled)
        )
        #expect(monocle == "App Bar in Monocle")
        #expect(SettingsCatalog.bars.monocleShowIn.text == monocle)
        let scrolling = SettingsCensusLabel.label(
            for: .layoutAppBar(.scrollingAppBarEnabled)
        )
        #expect(scrolling == "App Bar in Scrolling")
        #expect(SettingsCatalog.bars.scrollingShowIn.text == scrolling)
    }

    /// Which layout a label names is declared twice — on the
    /// catalog control (`naming:`) and on the census row
    /// (`labelMode`) — so every control, by reflection, is held
    /// to agree with the row that shares its label key, and a
    /// template label is one that names a layout, both ways.
    @Test("every catalog control and its census row name one layout")
    func declarationsAgree() {
        let english = LocaleCatalog.load("en")
        let censusModes = Dictionary(
            SettingKey.allCases.compactMap {
                key -> (String, LayoutMode?)? in
                guard case .key(let label) = key.text.label else {
                    return nil
                }
                return (label, key.labelMode)
            },
            uniquingKeysWith: { first, _ in first }
        )
        var joined = 0
        for destination in SettingsDestination.allCases {
            for entry in SettingsCatalog.entries(of: destination) {
                let control = entry.control
                guard let key = control.key else { continue }
                let template = english[key]?.contains("%1$") == true
                #expect(
                    template == (control.namedMode != nil),
                    "\(key): a template names a layout, and only one"
                )
                guard let censusMode = censusModes[key] else {
                    continue
                }
                joined += 1
                #expect(
                    censusMode == control.namedMode,
                    "\(key): census and catalog name different layouts"
                )
            }
        }
        // Non-vacuous: the join reaches the census rows the
        // catalog names, the two Show switches among them.
        #expect(joined > 20, "joined \(joined)")
        for key in SettingKey.allCases where key.labelMode != nil {
            guard case .key(let label) = key.text.label else {
                Issue.record("\(key.id) names a layout with no label")
                continue
            }
            #expect(english[label]?.contains("%1$") == true)
        }
    }
}
