import AppKit
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A labelled Space Bar preview item measures what the strip draws
/// (#2890): a text name or a symbol, in the bar's own face and on
/// the bar's own axis, so `ShelfStripPreview.need` counts a long
/// name's whole width. Main-actor spend: one hosted `BarStripView`
/// sized per case.
@Suite("Preview Space item length")
@MainActor
struct SpaceItemLengthTests {
    private static let scale: CGFloat = 1.8

    private static func spaceSpec(
        _ labels: [SpaceGlyph],
        vertical: Bool
    ) -> HomeCardBarsTile.BarSpec {
        let tile = HomeCardBarsTile(
            settings: TilingSettings(),
            pocketStands: false,
            spaceCount: labels.count,
            scale: scale,
            spaceLabels: labels
        )
        return tile.spaceSpec(tile.settings.spaceBarLook, vertical: vertical)
    }

    /// The drawn length of a run holding `item` alone, less the
    /// run's own padding, measured from the rendered strip.
    private static func drawnLength(
        _ item: HomeCardBarsTile.BarItem,
        spec: HomeCardBarsTile.BarSpec,
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

    @Test(
        "A long text name's length is what it draws",
        arguments: [false, true]
    )
    func textLengthIsDrawn(vertical: Bool) throws {
        let spec = Self.spaceSpec(
            [.text("Research", tinted: false)],
            vertical: vertical
        )
        let item = try #require(spec.items.first)
        let drawn = Self.drawnLength(item, spec: spec, vertical: vertical)
        let inset = spec.pipEndInset(scale: Self.scale)
        #expect(abs(item.length + 2 * inset - drawn) <= 1)
        if !vertical { #expect(item.length > 12 * Self.scale) }
    }

    @Test("A symbol's length is what it draws")
    func symbolLengthIsDrawn() throws {
        let spec = Self.spaceSpec([.symbol("house")], vertical: false)
        let item = try #require(spec.items.first)
        let drawn = Self.drawnLength(item, spec: spec, vertical: false)
        let inset = spec.pipEndInset(scale: Self.scale)
        #expect(abs(item.length + 2 * inset - drawn) <= 1)
    }
}
