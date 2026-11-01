import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The Layout Defaults chooser strip (#2901): all six tiles fit a
/// full-width pane, a narrower one fades the end that cuts a tile,
/// and a Tab onto a tile scrolls it into view.
@Suite("Layout chooser strip")
struct LayoutStripTests {
    private static func squashed(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(file)
        return SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    /// The scroller's viewport at the widest pane: the content
    /// column less the pane insets, widened by the ring room the
    /// strip's negative padding gives back.
    private static var widestViewport: CGFloat {
        SettingsTheme.contentMaxWidth - 2 * SettingsMetrics.paneInset
            + 2 * LayoutStrip.ringRoom
    }

    @Test("all six tiles fit the widest pane")
    func sixFit() {
        #expect(LayoutStrip.rowWidth <= Self.widestViewport)
        let fades = LayoutStrip.fades(
            offset: 0,
            viewport: Self.widestViewport
        )
        #expect(fades.leading == 0 && fades.trailing == 0)
    }

    @Test("a narrow strip fades only an end that cuts a tile")
    func fadesFollowTheOffset() {
        let viewport: CGFloat = 460
        let rest = LayoutStrip.fades(offset: 0, viewport: viewport)
        #expect(rest.leading == 0 && rest.trailing > 0)
        let mid = LayoutStrip.fades(offset: 200, viewport: viewport)
        #expect(mid.leading > 0 && mid.trailing > 0)
        let end = LayoutStrip.fades(
            offset: LayoutStrip.rowWidth - viewport,
            viewport: viewport
        )
        #expect(end.leading > 0 && end.trailing == 0)
    }

    /// An edge in the gap cuts no tile, yet the next one is wholly
    /// hidden: the fade still shows, at either end.
    @Test("an edge in a gap still fades the hidden tile")
    func edgeInAGapFades() {
        let first = LayoutStrip.ringRoom + LayoutStrip.tileWidth
        let viewport = first + LayoutStrip.gap / 2
        let rest = LayoutStrip.fades(offset: 0, viewport: viewport)
        #expect(rest.trailing > 0)
        let end = LayoutStrip.fades(
            offset: LayoutStrip.rowWidth - viewport,
            viewport: viewport
        )
        #expect(end.leading > 0)
    }

    /// A Tab onto the first hidden tile lands it clear of the
    /// trailing fade, and one back onto the first clear of the
    /// leading fade.
    @Test("Tab focus lands a tile clear of the fade")
    func followClearsTheFade() throws {
        let viewport: CGFloat = 460
        let tile = LayoutStrip.tileWidth
        let margin = ShelfOverflow.followMargin(
            gap: LayoutStrip.gap,
            depth: LayoutStrip.depth,
            viewport: viewport
        )
        let ahead = try #require(
            LayoutStrip.followAnchor(
                index: 3,
                offset: 0,
                viewport: viewport
            )
        )
        let lead = ahead.x * (viewport - tile)
        #expect(lead + tile <= viewport - margin + 0.5)
        let end = LayoutStrip.rowWidth - viewport
        let back = try #require(
            LayoutStrip.followAnchor(
                index: 1,
                offset: end,
                viewport: viewport
            )
        )
        #expect(back.x * (viewport - tile) >= margin - 0.5)
        // A tile already clear asks for no scroll.
        let clear = LayoutStrip.followAnchor(
            index: 0,
            offset: 0,
            viewport: viewport
        )
        #expect(clear == nil)
    }

    @Test("the strip is masked, measured and follows Tab focus")
    func wiring() throws {
        let strip = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Layouts/"
                + "LayoutStrip.swift"
        )
        #expect(strip.contains(".mask(StripFade(fades:fades))"))
        // The live offset and viewport feed the fade and the follow.
        #expect(strip.contains("Self.fades(offset:offset,viewport:viewport)"))
        #expect(
            strip.contains(
                "Self.followAnchor(index:index,offset:offset,"
                    + "viewport:viewport)"
            )
        )
        #expect(strip.contains("action:{offset=$0}"))
        #expect(strip.contains("-$0.frame(in:.named(Self.space)).minX"))
        #expect(strip.contains(".coordinateSpace(.named(Self.space))"))
        #expect(strip.contains(".focused($focused,equals:mode)"))
        #expect(strip.contains(".id(mode)"))
        #expect(
            strip.contains(
                ".onChange(of:focused){_,modein"
                    + "follow(mode,with:proxy)}"
            )
        )
        #expect(strip.contains("proxy.scrollTo(mode,anchor:anchor)"))
        #expect(
            strip.contains("schematic(mode).padding(Self.platePadding)")
        )
        #expect(
            strip.contains(
                ".padding(Self.chromePadding)"
                    + ".frame(width:Self.tileWidth)"
            )
        )
        // The ring room sits inside the clip, given back outside.
        #expect(strip.contains(".padding(Self.ringRoom)"))
        #expect(strip.contains(".padding(.horizontal,-Self.ringRoom)"))
    }

    @Test("the thumbnail is drawn at the strip's scale")
    func schematicIsScaled() throws {
        let metrics = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Layouts/"
                + "LayoutStrip+Metrics.swift"
        )
        #expect(
            metrics.contains(
                ".scaleEffect(factor).frame(width:Self.schematicWidth,"
                    + "height:Self.depth)"
            )
        )
        // The fades call itself, not followMargin's twin.
        #expect(
            metrics.contains("offset:offset,viewport:viewport,depth:depth)")
        )
    }
}
