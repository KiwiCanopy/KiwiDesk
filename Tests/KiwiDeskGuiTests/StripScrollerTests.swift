import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// A sideways strip in Settings keeps the platform's scroller, which
/// a mouse user needs to reach what it cuts (#2901). Scans source
/// off the main actor; whether macOS draws it is a device check.
///
/// Both walks read every site's arguments instead of matching a hide's
/// spelling. They trade reach for that: a modifier wrapped in a helper
/// that takes the visibility as a value is not seen at the wrapper's
/// caller.
@Suite("Settings strip scroller")
struct StripScrollerTests {
    private static func settingsSources() throws -> [(String, String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        return try SourceScan.swiftSources(under: root).map { url in
            let source = try SourceScan.strippedSource(at: url)
            return (
                url.lastPathComponent,
                source.split(whereSeparator: \.isWhitespace).joined()
            )
        }
    }

    /// What follows each occurrence of `needle`.
    private static func tails(of needle: String, in source: String)
        -> [Substring]
    {
        source.components(separatedBy: needle).dropFirst().map {
            Substring($0)
        }
    }

    @Test("no Settings scroll view hides its scroller by argument")
    func noHiddenArgument() throws {
        let sources = try Self.settingsSources()
        #expect(sources.contains { $0.1.contains("ScrollView(.horizontal") })
        for (name, source) in sources {
            for tail in Self.tails(of: "showsIndicators:", in: source) {
                #expect(
                    tail.hasPrefix("true)") || tail.hasPrefix("true,"),
                    "\(name) hides a scroller"
                )
            }
        }
    }

    /// The modifier is documented to reach nested scroll views, so any
    /// hide beyond the vertical axis also hides a strip below it.
    @Test("a hiding modifier names only the vertical axis")
    func hidingIsVerticalOnly() throws {
        let allowed = [
            ".automatic)", ".automatic,", ".visible)", ".visible,",
            ".hidden,axes:.vertical)",
        ]
        var sites = 0
        for (name, source) in try Self.settingsSources() {
            // The modifier's environment value is the same hide.
            #expect(
                !source.contains("horizontalScrollIndicatorVisibility"),
                "\(name) hides a strip through the environment"
            )
            for tail in Self.tails(of: ".scrollIndicators(", in: source) {
                sites += 1
                #expect(
                    allowed.contains { tail.hasPrefix($0) },
                    "\(name) hides more than the vertical axis"
                )
            }
        }
        #expect(sites > 0)
    }

    /// Room only where an overlay scroller draws over the content: a
    /// strip that fits draws no scroller, and SwiftUI already grows the
    /// scroll view by a legacy one.
    @Test("the clearance answers the overflow and the scroller style")
    func clearance() {
        let room = StripScrollerRoom.room
        #expect(
            room(true, .overlay) == StripScrollerRoom.overlayHeight
        )
        #expect(StripScrollerRoom.overlayHeight > 0)
        #expect(room(false, .overlay) == 0)
        #expect(room(true, .legacy) == 0)
        #expect(room(false, .legacy) == 0)
    }

    /// The modifier is the one home: only it pads for a scroller or
    /// reads the style, and each strip's overflow is its own reading.
    @Test("the clearance has one home and both strips take it")
    func clearanceHome() throws {
        let sources = try Self.settingsSources()
        let readers = sources.filter {
            $0.1.contains("preferredScrollerStyle")
        }
        #expect(readers.map(\.0) == ["StripScrollerRoom.swift"])
        let takers = Dictionary(
            uniqueKeysWithValues: sources.filter {
                $0.1.contains("StripScrollerRoom")
            }
        )
        #expect(
            Set(takers.keys) == [
                "StripScrollerRoom.swift", "SidewaysStrip.swift",
                "SpacesPanelPreview.swift",
            ]
        )
        let home = try #require(takers["StripScrollerRoom.swift"])
        #expect(
            home.contains(
                ".padding(.bottom,Self.room(overflows:overflows,style:style))"
            )
        )
        #expect(
            home.contains(
                "preferredScrollerStyleDidChangeNotification"
            )
        )
        #expect(
            takers["SidewaysStrip.swift"]?.contains(
                ".modifier(StripScrollerRoom("
                    + "overflows:run.total>scroll.viewport))"
            ) == true
        )
        #expect(
            takers["SpacesPanelPreview.swift"]?.contains(
                ".modifier(StripScrollerRoom("
                    + "overflows:chipsWidth>chipsViewport))"
            ) == true
        )
        let preview = try #require(takers["SpacesPanelPreview.swift"])
        #expect(preview.contains("action:{chipsWidth=$0}"))
        #expect(preview.contains("action:{chipsViewport=$0}"))
    }
}
