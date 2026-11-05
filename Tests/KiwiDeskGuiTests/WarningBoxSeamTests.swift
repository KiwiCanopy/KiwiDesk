import Foundation
import Testing

@testable import KiwiDesk

/// Settings draws one warning surface (#2982): a fill of its own
/// beside `WarningBox` draws a warning that reads differently. The
/// fill clause keys on the token, so a warning on another fill passes
/// it; the site clause fails apart, on a site that leaves the box.
/// Scans source only, off the main actor.
@Suite("Warning box seam")
struct WarningBoxSeamTests {
    @Test("only the box fills the warning surface")
    func oneFill() throws {
        var found: [String: Int] = [:]
        for url in try ChromeScanRoots.sources(from: #filePath) {
            let count = try SourceScan.strippedSource(at: url)
                .filter { !$0.isWhitespace }
                .occurrences(of: "SettingsTheme.warningSurface")
            if count > 0 {
                found[url.lastPathComponent] = count
            }
        }
        #expect(found == ["WarningBox.swift": 1])
    }

    @Test("the banner and the sync sheet draw the box")
    func sitesTakeTheBox() throws {
        let needles = [
            "KeybindingConflictBanner.swift":
                "WarningBox(text:message){Button{"
                + "model.keybindingWarning=nil",
            "SyncReviewSheet.swift": "WarningBox(text:SyncText.pickEach)",
        ]
        let sources = try ChromeScanRoots.sources(from: #filePath)
        for (name, needle) in needles {
            let url = try #require(
                sources.first { $0.lastPathComponent == name }
            )
            let source = try SourceScan.strippedSource(at: url)
                .filter { !$0.isWhitespace }
            #expect(source.contains(needle), "\(name)")
        }
    }
}
