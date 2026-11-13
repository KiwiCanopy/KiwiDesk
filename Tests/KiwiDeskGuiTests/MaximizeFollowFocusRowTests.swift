import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Maximize card's "Maximize follows focus" row (#3280) writes
/// the profile value `maximize.set_follow_focus` writes, and is no
/// longer a Lua-only census row.
@Suite("Maximize follows focus row (#3280)")
struct MaximizeFollowFocusRowTests {
    @Test("the census places the row in the Maximize card")
    func censusPlacesTheRow() {
        let key = SettingKey.behaviour(.maximizeFollowFocus)
        #expect(key.id == "settings.maximize.followFocus")
        #expect(key.placement.area == .layoutDefaults)
        #expect(key.placement.container == .maximize)
        #expect(key.placement.tier == .atRest)
        #expect(
            !LayoutDefaultsRowOrder.maximizeColumns.contains(key)
        )
    }

    /// The census label, the catalog anchor and the row's label are
    /// one key, so search lands on the row it names.
    @Test("the row's label is the census and catalog key")
    @MainActor
    func labelIsOneKey() {
        let control = SettingsCatalog.layoutDefaults.maximizeFollowFocus
        #expect(control.key == "layout_defaults.maximize.follow_focus")
        let text = BehaviourKey.maximizeFollowFocus.text
        #expect(text.label == .key(control.key ?? ""))
        #expect(
            text.helpKey == "layout_defaults.maximize.follow_focus.help"
        )
    }

    /// The toggle binds the draft's `maximize.followFocus`, the leaf
    /// the Lua verb writes, and anchors the catalog control.
    @Test("the toggle writes the stored follow-focus value")
    func toggleWritesTheStoredValue() throws {
        let source = try cardSource()
        #expect(
            source.contains(
                "ToggleRow(label:controls.maximizeFollowFocus.text,"
                    + "isOn:$model.config.settings.maximize.followFocus,"
                    + "help:Self.followFocusHelp)"
                    + ".searchAnchored("
                    + "SettingsCatalog.layoutDefaults.maximizeFollowFocus)"
            )
        )
    }

    private func cardSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "MaximizeCard.swift"
            )
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
    }
}
