import Foundation
import Testing

@testable import KiwiDesk

/// The Settings half of sticky reach (#1145): the row is the one
/// surfacing branch the resolver cannot see — hidden without the
/// bridge, never greyed — and the search index carries it only
/// when the bridge is up.
@Suite("Sticky reach Settings row")
struct StickyReachRowTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// gui.md's `surfacingBranchesAreDrawn` class: a source
    /// needle, since a GUI suite cannot reach the live bridge.
    @Test("the sticky-reach row is drawn behind the capability")
    func settingsRowSurfaces() throws {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings/Components/"
                + "GapsAndBorders/StickyMarkEditor.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        .replacingOccurrences(of: " ", with: "")
        .replacingOccurrences(of: "\n", with: "")
        #expect(
            source.contains(
                "ifmodel.canDriveDesktops{ToggleRow(label:L("
                    + "\"sticky.desktop_reach\","
            )
        )
    }

    /// The capability-PRESENT branch of the search filter — the
    /// mirrors are pinned false everywhere else, so without
    /// this the true side is exercised by nothing (#1145
    /// review). Process-global: sets the static and resets.
    @Test("the search index carries the row when the bridge is up")
    @MainActor
    func searchIndexesTheRowWithTheBridge() {
        let before = SettingsSearchIndex.canDriveDesktops
        defer { SettingsSearchIndex.canDriveDesktops = before }
        SettingsSearchIndex.canDriveDesktops = false
        #expect(
            !SettingsSearchIndex.indexes(
                .borders(.stickyDesktopReach)
            )
        )
        SettingsSearchIndex.canDriveDesktops = true
        #expect(
            SettingsSearchIndex.indexes(
                .borders(.stickyDesktopReach)
            )
        )
    }
}
