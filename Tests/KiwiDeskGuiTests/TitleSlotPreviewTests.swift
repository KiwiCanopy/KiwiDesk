import AppKit
import KiwiDeskCore
import SwiftUI
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
        let tile = HomeCardBarsTile(
            settings: settings,
            pocketStands: false,
            scale: 1.8
        )
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
        let tile = HomeCardBarsTile(
            settings: TilingSettings(),
            pocketStands: false,
            scale: 1.8
        )
        #expect(tile.spaceSpec(tile.settings.spaceBarLook).titleSlot == nil)
    }

    /// The strip's title sizes to itself up to the slot, never
    /// to the slot whatever it reads, so the icon and title centre
    /// together in the slot's length as the live bar draws them
    /// (#2643). Measured, since a short title stretched to the slot
    /// spells alike.
    @Test("A preview title is its own width, the slot at most")
    func titleSizesToItself() {
        let slot: CGFloat = 120
        let width = { (text: String, offer: CGFloat) -> CGFloat in
            let host = NSHostingController(
                rootView: BarStripSlotTitle(slot: slot) {
                    Text(text).font(.system(size: 13)).lineLimit(1)
                }
            )
            return host.sizeThatFits(
                in: CGSize(width: offer, height: 40)
            ).width
        }
        let short = width("Mail", 400)
        #expect(short > 0)
        #expect(short < slot / 2)
        #expect(abs(width("Mail", 60) - short) < 0.5)
        let long = String(repeating: "A long window title ", count: 4)
        // Cut with "…" at a glyph boundary: up to the slot, never
        // past it, and well beyond a short title.
        let cut = width(long, 400)
        #expect(cut <= slot + 0.5)
        #expect(cut > slot * 0.8)
        #expect(width(long, 80) <= 80.5)
    }

    /// The strip holds the slot in a hidden twin and draws its title
    /// through `BarStripSlotTitle`, never framed to the slot itself.
    /// Syntax only: a strip that stretches or leads its group some
    /// other way stays green here, since no clause renders the strip.
    @Test("The strip frames a title in the slot")
    func stripFramesTheTitle() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/HomeCardPlate+BarStrip.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        #expect(source.occurrences(of: "frame(width: spec.titleSlot") == 1)
        #expect(
            source.occurrences(
                of: "BarStripSlotTitle(slot: spec.titleSlot)"
            ) == 1
        )
        // The group centres in the twin, and the title is never
        // stretched past its own width.
        #expect(source.occurrences(of: "ZStack(alignment:") == 0)
        let start = try #require(
            source.range(of: "func iconAndTitle(")
        )
        let end = try #require(
            source.range(
                of: "func indicatorMark(",
                range: start.upperBound..<source.endIndex
            )
        )
        let body = String(source[start.upperBound..<end.lowerBound])
        #expect(body.contains("BarStripSlotTitle("))
        #expect(!body.contains("maxWidth:"))
    }
}
