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

    @Test("the strip is masked, measured and follows Tab focus")
    func wiring() throws {
        let strip = try Self.squashed(
            "Sources/KiwiDesk/Settings/Components/Layouts/"
                + "LayoutStrip.swift"
        )
        #expect(strip.contains(".mask(StripFade(fades:fades))"))
        #expect(strip.contains("-$0.frame(in:.named(Self.space)).minX"))
        #expect(strip.contains(".coordinateSpace(.named(Self.space))"))
        #expect(strip.contains(".focused($focused,equals:mode)"))
        #expect(strip.contains(".id(mode)"))
        #expect(strip.contains("proxy.scrollTo(mode)"))
        // The ring room sits inside the clip, given back outside.
        #expect(strip.contains(".padding(Self.ringRoom)"))
        #expect(strip.contains(".padding(.horizontal,-Self.ringRoom)"))
        #expect(strip.contains(".frame(width:Self.tileWidth)"))
    }
}
