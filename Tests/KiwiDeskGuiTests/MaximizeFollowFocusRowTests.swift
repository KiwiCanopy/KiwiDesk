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

    /// The card's body walks its order list right after the chord
    /// captions, in the section's own content and under no `if`, and
    /// `row(_:)`'s follow-focus arm binds the draft's
    /// `maximize.followFocus`, the leaf the Lua verb writes, and
    /// anchors the catalog control. Scoped to the two bodies, since
    /// a needle read over the file passes on a dead helper.
    @Test("the card walks the list and the toggle writes the value")
    func cardWalksTheList() throws {
        let source = try strippedCard()
        let body = try #require(
            SourceScan.declarationBody(
                after: "var body: some View",
                in: source
            )
        )
        let row = try #require(
            SourceScan.declarationBody(
                after: "private func row(_ key: SettingKey)",
                in: source
            )
        )
        #expect(Self.squeezed(body).contains(Self.walk))
        #expect(Self.squeezed(row).contains(Self.toggleArm))
    }

    /// The walk, glued to the chord caption before it and the
    /// section's closing brace after it: the glue keeps the walk out
    /// of any conditional, and is no value pin.
    private static let walk = [
        "row:SettingsCatalog.shortcuts.maximizeWidthBinding)}",
        "ForEach(Self.rowsBelowTable,id:\\.id){keyinrow(key)}}",
    ].joined()

    /// The follow-focus arm, spaces and newlines stripped.
    private static let toggleArm = [
        "case.behaviour(.maximizeFollowFocus):",
        "ToggleRow(label:controls.maximizeFollowFocus.text,",
        "isOn:$model.config.settings.maximize.followFocus,",
        "help:Self.followFocusHelp)",
        ".searchAnchored(",
        "SettingsCatalog.layoutDefaults.maximizeFollowFocus)",
    ].joined()

    private func strippedCard() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts/"
                    + "MaximizeCard.swift"
            )
        return try SourceScan.strippedSource(at: url)
    }

    private func cardSource() throws -> String {
        Self.squeezed(try strippedCard())
    }

    private static func squeezed(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
}
