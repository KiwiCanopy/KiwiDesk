import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A mock App Bar item measures what the strip draws (#2781): above
/// scale 1 it draws its icon alone, so its length — which
/// `ShelfStripPreview.need` sums — is that glyph and its padding,
/// and a 1.8× panel frame draws as many as its strip holds whole.
@Suite("Mock App Bar item length")
@MainActor
struct MockAppItemLengthTests {
    private static func appSpec(
        scale: CGFloat,
        vertical: Bool = false
    ) -> HomeCardBarsTile.BarSpec {
        let tile = HomeCardBarsTile(
            settings: TilingSettings(),
            pocketStands: false,
            scale: scale
        )
        return tile.appSpec(
            tile.settings.appBarLook(for: tile.settings.appBarHosts[0]),
            vertical: vertical
        )
    }

    /// The drawn length of a run holding `item` alone, less the
    /// run's own padding, measured from the rendered strip.
    private static func drawnLength(
        _ item: HomeCardBarsTile.BarItem,
        spec: HomeCardBarsTile.BarSpec,
        scale: CGFloat,
        vertical: Bool
    ) -> CGFloat {
        var one = spec
        one.items = [item]
        one.boxed = false
        let host = NSHostingController(
            rootView: BarStripView(
                spec: one,
                edge: vertical ? .left : .top,
                vertical: vertical,
                scale: scale,
                drawsPlate: false
            )
            .fixedSize()
        )
        let size = host.sizeThatFits(
            in: CGSize(width: 4000, height: 4000)
        )
        let along = vertical ? size.height : size.width
        return along - 2 * one.gap - 2 * 3 * scale
    }

    @Test("An icon item's length is what it draws", arguments: [false, true])
    func iconLengthIsDrawn(vertical: Bool) throws {
        let scale: CGFloat = 1.8
        let spec = Self.appSpec(scale: scale, vertical: vertical)
        #expect(spec.items.count == 3)
        for item in spec.items {
            #expect(item.glyph != nil)
            #expect(item.label == nil)
            let drawn = Self.drawnLength(
                item,
                spec: spec,
                scale: scale,
                vertical: vertical
            )
            #expect(abs(drawn - item.length) < 1, "\(drawn) vs \(item.length)")
        }
    }

    @Test("At scale 1 an item stays a bare pip")
    func bareKeepsLength() throws {
        let spec = Self.appSpec(scale: 1)
        let first = try #require(spec.items.first)
        #expect(first.glyph == nil)
        #expect(first.length == 20)
    }

    /// The shortest panel frame's strip: its schematic screen fitted
    /// to the frame's height less its pads, less the screen's inset
    /// (`BarsPanelPreview.framed`, `HomeCardBarsTile.body`).
    private static let panelStrip: CGFloat =
        (BarsPanelPreview.shortFrame - 2 * BarsPanelPreview.framePad)
        * HomeCardBarsTile.screenAspect
        - 2 * HomeCardBarsTile.screenInset

    /// The panel's Spaces and mock items fit its strip whole,
    /// Plain and Boxed, so neither bar fades (owner, #2781).
    @Test("A panel frame's bars fit its strip", arguments: [false, true])
    func panelBarsFit(boxed: Bool) throws {
        let scale: CGFloat = 1.8
        var settings = TilingSettings()
        if boxed { settings.kiwishelf.backgroundStyle = .boxed }
        let tile = HomeCardBarsTile(
            settings: settings,
            pocketStands: false,
            spaceCount: BarsPanelPreview.spaces,
            scale: scale,
            mockApps: BarsPanelPreview.mockApps
        )
        let space = tile.spaceSpec(tile.settings.spaceBarLook, vertical: false)
        let app = tile.appSpec(
            tile.settings.appBarLook(for: tile.settings.appBarHosts[0]),
            vertical: false
        )
        #expect(app.items.count == BarsPanelPreview.mockApps)
        let strip = ShelfStripPreview(
            shelf: tile.settings.kiwishelf,
            space: space,
            app: app,
            edge: .top,
            vertical: false,
            scale: scale,
            pocket: false
        )
        let placed = strip.arrangement(length: Self.panelStrip)
        let appSlot = try #require(placed.app)
        let spaceSlot = try #require(placed.space)
        #expect(appSlot.length >= strip.need(app) - 0.5)
        #expect(spaceSlot.length >= strip.need(space) - 0.5)
    }

    /// On a thick bar even two mock items overflow the panel's
    /// strip, so the strip drops them from the end until the rest
    /// fit whole, never cutting the Space Bar's (#2781).
    @Test("A thick panel strip drops mock items it cannot fit")
    func thickStripDropsMocks() throws {
        let scale: CGFloat = 1.8
        var settings = TilingSettings()
        settings.kiwishelf.backgroundStyle = .boxed
        settings.kiwishelf.thickness = 80
        let tile = HomeCardBarsTile(
            settings: settings,
            pocketStands: false,
            spaceCount: BarsPanelPreview.spaces,
            scale: scale,
            mockApps: BarsPanelPreview.mockApps
        )
        let space = tile.spaceSpec(tile.settings.spaceBarLook, vertical: false)
        let app = tile.appSpec(
            tile.settings.appBarLook(for: tile.settings.appBarHosts[0]),
            vertical: false
        )
        let strip = ShelfStripPreview(
            shelf: tile.settings.kiwishelf,
            space: space,
            app: app,
            edge: .top,
            vertical: false,
            scale: scale,
            pocket: false
        )
        let whole = try #require(
            strip.arrangement(length: Self.panelStrip).app
        )
        #expect(strip.overflows(app, whole), "fixture must overflow")
        let fitted = strip.fitted(length: Self.panelStrip)
        let kept = try #require(fitted.app)
        #expect(kept.items.count >= 1)
        #expect(kept.items.count < app.items.count)
        #expect(fitted.space?.items.count == space.items.count)
        let slot = try #require(
            fitted.arrangement(length: Self.panelStrip).app
        )
        #expect(!fitted.overflows(kept, slot))
    }

    /// The strip draws its fitted copy, so the trim reaches the
    /// screen. Syntax only: a body that fits and then draws `self`
    /// stays green here.
    @Test("The strip draws its fitted copy")
    func stripDrawsFitted() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/HomeCardPlate+ShelfStrip.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
        #expect(
            source.occurrences(
                of: "fitted(length: length).drawn(length: length)"
            ) == 1
        )
    }

    /// Under Boxed every pip wears its box's padding, and the run's
    /// need counts it: a boxed run draws exactly its measured items,
    /// their insets, its gaps and its own padding.
    @Test("A boxed run measures its boxes' padding")
    func boxedRunMeasuresItsPadding() {
        let scale: CGFloat = 1.8
        var spec = Self.appSpec(scale: scale)
        spec.boxed = true
        spec.spans = false
        let host = NSHostingController(
            rootView: BarStripView(
                spec: spec,
                edge: .top,
                vertical: false,
                scale: scale,
                drawsPlate: false
            )
            .fixedSize()
        )
        let drawn = host.sizeThatFits(
            in: CGSize(width: 4000, height: 4000)
        ).width
        let measured =
            spec.items.map(\.length).reduce(0, +)
            + spec.pipEndInsets(scale: scale)
            + spec.gap * CGFloat(spec.items.count - 1)
            + 2 * 3 * scale
        #expect(abs(drawn - measured) < 1, "\(drawn) vs \(measured)")
    }

}
