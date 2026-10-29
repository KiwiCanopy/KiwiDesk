import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A Space's own minimum window size row (#2422): its gate, what it
/// follows, its seed and its place in the overrides box.
@MainActor
@Suite("Per-Space minimum window size row (#2422)")
struct OverrideMinSizeRowTests {
    private static let dir =
        "Sources/KiwiDesk/Settings/Components/SpaceOverrides/"

    private static func source(_ file: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
        return try SourceScan.strippedSource(
            at: root.appendingPathComponent(dir + file)
        ).filter { !$0.isWhitespace }
    }

    @Test("a Monocle Space greys the row, every other layout does not")
    func monocleIsInert() {
        let key = SettingKey.behaviour(.minSizePerSpaceOverride)
        for mode in LayoutMode.allCases {
            let gates = SpacesGates(
                settings: TilingSettings(),
                space: SpaceID("2"),
                mode: mode
            )
            #expect(
                gates.inertReason(for: key)
                    == (mode == .monocle ? .monocleAppliesNone : nil)
            )
        }
    }

    @Test("checking the row copies the followed value exactly")
    func checkingPrefillsFromTheLayout() {
        var stored: MinSize? = nil
        let binding = Binding(get: { stored }, set: { stored = $0 })
        let grid = MinSize(width: 220, height: 160)
        overrideToggle(binding, global: grid).wrappedValue = true
        #expect(stored == grid)
        overrideToggle(binding, global: grid).wrappedValue = false
        #expect(stored == nil)
    }

    /// Below the gaps on every mode, writing the Space's own map,
    /// following its layout's resolved value and naming it only
    /// where that layout stands apart; greyed through the resolver.
    @Test("the box draws the row after the gaps through its gate")
    func boxDrawsTheRow() throws {
        let box = try Self.source("SpaceOverrideRows.swift")
        #expect(box.contains("gapsRowminSizeRowDivider()modeRows"))
        let row = try Self.source("SpaceOverrideRows+MinSize.swift")
        #expect(
            row.contains(
                "value:$model.config.settings"
                    + ".minWindowSizeOverride[space]"
            )
        )
        #expect(
            row.contains("followed:g.minWindowSize(for:minSizeMode,in:nil)")
        )
        #expect(row.contains("model.minSizeStandsApart(layout)"))
        #expect(
            row.contains(
                "gates.inertReason("
                    + "for:.behaviour(.minSizePerSpaceOverride))"
            )
        )
        #expect(
            row.contains("row.modifier(GreyOut(active:true,help:sentence))")
        )
        #expect(row.contains("Text(sentence)"))
    }

    /// The button's live count is what keeps a Floating Space's
    /// badge honest; the pure verdict cannot see the call.
    @Test("the Customize button hands the live count to its verdict")
    func cellPassesTheLiveCount() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let cell = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/"
                    + "SpaceCustomizeButton.swift"
            )
        ).filter { !$0.isWhitespace }
        #expect(
            cell.contains(
                "OverrideCellState.resolve(count:settings"
                    + ".spaceOverrideCount(for:space),live:settings"
                    + ".floatingLiveOverrideCount(for:space)"
            )
        )
    }

    @Test("the row seeds and steps from what it follows")
    func rowSeedsFromTheFollowed() throws {
        let row = try Self.source("OverrideMinSizeRow.swift")
        #expect(row.contains("overrideToggle($value,global:followed)"))
        #expect(row.contains("inheritsName:followedName"))
        #expect(row.contains("base:{Int(followed[$0])}"))
        #expect(row.contains("MinSizeFields("))
    }
}
