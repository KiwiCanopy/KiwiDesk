import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Maximize card's "Maximize follows focus" row (#3280) writes
/// the profile value `maximize.set_follow_focus` writes.
@Suite("Maximize follows focus row (#3280)")
struct MaximizeFollowFocusRowTests {
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

    /// The row's `?` reads the census help key.
    @Test("the row's help is the census help key")
    func helpIsTheCensusKey() throws {
        let help = try #require(BehaviourKey.maximizeFollowFocus.text.helpKey)
        let needle = "staticvarfollowFocusHelp:String{L(\"\(help)\","
        let source = try cardSource()
        #expect(source.contains(needle))
    }

    /// The card walks its order list below the table, and the
    /// follow-focus arm binds the draft's `maximize.followFocus`, the
    /// leaf the Lua verb writes, and anchors the catalog control.
    @Test("the card walks the list and the toggle writes the value")
    func cardWalksTheList() throws {
        let source = try cardSource()
        #expect(
            source.contains(
                "ForEach(Self.rowsBelowTable,id:\\.id){keyinrow(key)}"
            )
        )
        #expect(source.contains(Self.toggleArm))
    }

    /// The follow-focus arm, spaces and newlines stripped.
    private static let toggleArm = [
        "case.behaviour(.maximizeFollowFocus):",
        "ToggleRow(label:controls.maximizeFollowFocus.text,",
        "isOn:$model.config.settings.maximize.followFocus,",
        "help:Self.followFocusHelp)",
        ".searchAnchored(",
        "SettingsCatalog.layoutDefaults.maximizeFollowFocus)",
    ].joined()

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
