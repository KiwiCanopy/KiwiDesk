import AppKit
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Bars preview draws the App Bar's fixed title slot (#2545):
/// its spec carries the draft's title cap, read through the live
/// bar's one `BarTitleSlot` at the frame's own font size, and the
/// strip frames each title in it.
@Suite("Title slot in the Bars preview")
@MainActor
struct TitleSlotPreviewTests {
    private static func appSpec(titleCap: Int) -> HomeCardBarsTile.BarSpec {
        var settings = TilingSettings()
        settings.appBarStyle.titleCap = titleCap
        let tile = HomeCardBarsTile(settings: settings, scale: 1.8)
        return tile.appSpec(
            tile.settings.appBarLook(for: tile.settings.appBarHosts[0]),
            vertical: false
        )
    }

    @Test("The App Bar's spec carries the live bar's slot")
    func specCarriesTheSlot() throws {
        let spec = Self.appSpec(titleCap: 12)
        #expect(spec.titleCap == 12)
        let slot = try #require(spec.titleSlot)
        #expect(
            slot
                == BarTitleSlot.length(
                    cap: 12,
                    font: spec.shelf.textFont(ofSize: spec.fontSize)
                )
        )
        let wider = try #require(Self.appSpec(titleCap: 24).titleSlot)
        #expect(wider > slot)
    }

    @Test("The Space Bar's spec carries no title slot")
    func spaceSpecHasNone() {
        let tile = HomeCardBarsTile(settings: TilingSettings(), scale: 1.8)
        #expect(tile.spaceSpec(tile.settings.spaceBarLook).titleSlot == nil)
    }

    /// The strip frames its title text in the spec's slot, at that
    /// width exactly: a bound on one side alone lets a short title
    /// size to itself.
    @Test("The strip frames a title in the slot")
    func stripFramesTheTitle() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/HomeCardPlate+BarStrip.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        #expect(source.occurrences(of: ".frame(width: spec.titleSlot)") == 1)
    }
}
