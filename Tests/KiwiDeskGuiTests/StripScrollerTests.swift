import AppKit
import Foundation
import Testing

@testable import KiwiDesk

/// A sideways strip in Settings or the first-launch tour keeps the
/// platform's scroller, which a mouse user needs to reach what it cuts
/// (#2901). Scans source off the main actor; whether macOS draws it is
/// a device check.
///
/// Both walks read every site's arguments instead of matching a hide's
/// spelling. They trade reach for that: a modifier wrapped in a helper
/// that takes the visibility as a value is not seen at the wrapper's
/// caller.
@Suite("Sideways strip scroller")
struct StripScrollerTests {
    private static func sources(in tree: String) throws -> [(String, String)] {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/\(tree)")
        return try SourceScan.swiftSources(under: root).map { url in
            let source = try SourceScan.strippedSource(at: url)
            return (
                url.lastPathComponent,
                source.split(whereSeparator: \.isWhitespace).joined()
            )
        }
    }

    private static func stripSources() throws -> [(String, String)] {
        try sources(in: "Settings") + sources(in: "Onboarding")
    }

    /// A scroll row's two widths on their own writes, and the modifier
    /// inside the scroll view.
    private static let measuredRoom =
        "ScrollView(.horizontal){content"
        + ".onGeometryChange(for:CGFloat.self){$0.size.width}"
        + "action:{width=$0}"
        + ".modifier(StripScrollerRoom("
        + "contentWidth:width,viewport:viewport))}"
        + ".onGeometryChange(for:CGFloat.self){$0.size.width}"
        + "action:{viewport=$0}"

    /// What follows each occurrence of `needle`.
    private static func tails(of needle: String, in source: String)
        -> [Substring]
    {
        source.components(separatedBy: needle).dropFirst().map {
            Substring($0)
        }
    }

    @Test("no strip's scroll view hides its scroller by argument")
    func noHiddenArgument() throws {
        let sources = try Self.stripSources()
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
        for (name, source) in try Self.stripSources() {
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
    /// strip that fits draws no scroller, an unmeasured one is not
    /// known to overflow, and SwiftUI already grows the scroll view by
    /// a legacy one.
    @Test("the clearance answers the overflow and the scroller style")
    func clearance() {
        let room = StripScrollerRoom.room
        #expect(
            room(200, 100, .overlay) == StripScrollerRoom.overlayHeight
        )
        #expect(StripScrollerRoom.overlayHeight > 0)
        #expect(room(100, 100, .overlay) == 0)
        #expect(room(50, 100, .overlay) == 0)
        #expect(room(200, 0, .overlay) == 0)
        #expect(room(200, 100, .legacy) == 0)
        #expect(room(50, 100, .legacy) == 0)
    }

    /// The modifier is the one reader of the style, and each strip
    /// takes it inside its scroll view, its widths read off the content
    /// and the scroll view. The needles are contiguous so the modifier
    /// stays inside the scroll view: a harmless modifier inside a span
    /// reds, and a bottom padding on what a host hands the strip is not
    /// seen.
    @Test("the clearance has one home and every strip takes it")
    func clearanceHome() throws {
        let sources = try Self.stripSources()
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
                "SpacesPanelPreview.swift", "OnboardingLooksRows.swift",
            ]
        )
        let home = try #require(takers["StripScrollerRoom.swift"])
        #expect(
            home.contains(
                ".padding(.bottom,Self.room(contentWidth:contentWidth,"
                    + "viewport:viewport,style:style))"
            )
        )
        #expect(
            home.contains(
                "preferredScrollerStyleDidChangeNotification"
            )
        )
        #expect(
            takers["SidewaysStrip.swift"]?.contains(
                "ScrollView(.horizontal){content"
                    + ".modifier(StripScrollerRoom("
                    + "contentWidth:run.total,viewport:scroll.viewport))"
            ) == true
        )
        #expect(
            takers["SpacesPanelPreview.swift"]?.contains(
                "SpacePreviewChipRow{HStack(spacing:6)"
            ) == true
        )
        #expect(
            takers["SpacesPanelPreview.swift"]?.contains(Self.measuredRoom)
                == true
        )
        try expectTourRowsTakeIt(takers)
    }

    /// Both rows take the one scroll row. The padding clause is
    /// file-wide, so a harmless bottom padding on a tile or a header
    /// here reds too: that is its price for seeing one beside a row.
    private func expectTourRowsTakeIt(_ takers: [String: String]) throws {
        let tour = try #require(takers["OnboardingLooksRows.swift"])
        #expect(tour.contains(Self.measuredRoom))
        let row = "OnboardingStripScroll{HStack(alignment:.top,spacing:8)"
        let rows = Self.tails(of: row, in: tour)
        #expect(rows.count == 2)
        #expect(!tour.contains(".padding(.bottom"))
    }

    /// `SidewaysStripTests` watches Settings only, so a new tour strip
    /// needs this count to meet the clearance. It reads each
    /// `ScrollView(`'s first argument, so an axis that opens `.vertical`
    /// is not seen.
    @Test("the tour's one sideways scroll view is the one with the room")
    func tourHolders() throws {
        var holders: [String: Int] = [:]
        for (name, source) in try Self.sources(in: "Onboarding") {
            for tail in Self.tails(of: "ScrollView(", in: source)
            where !tail.hasPrefix(".vertical") {
                holders[name, default: 0] += 1
            }
        }
        #expect(holders == ["OnboardingLooksRows.swift": 1])
    }
}
