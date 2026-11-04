import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// The one sideways scroller of a Settings strip (#2987), and the
/// Simple look line on it. The look line's run touches `PaletteTile`,
/// so its tests take the main actor, for arithmetic only.
@Suite("Sideways strip container")
struct SidewaysStripTests {
    private static let root = "Sources/KiwiDesk/Settings"

    private static func squashed(_ url: URL) throws -> String {
        try SourceScan.strippedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
    }

    private static func squashed(_ file: String) throws -> String {
        try squashed(
            SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(root + "/" + file)
        )
    }

    private static func settingsSources() throws -> [(String, String)] {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(root)
        return try SourceScan.swiftSources(under: url).map {
            ($0.lastPathComponent, try squashed($0))
        }
    }

    /// Who may hold a scroll view that is not plainly vertical, and
    /// how many. Reads each `ScrollView(`'s first argument, so an array
    /// or a variable axis counts; a helper that wraps one is not seen.
    private static let allowed: [String: (count: Int, why: String)] = [
        "SidewaysStrip.swift": (1, "the container itself"),
        "SpacesPanelPreview.swift": (
            1, "chip widths vary, so a run needs measuring first (#2990)"
        ),
        "ScreensPicture.swift": (
            1, "a two-axis canvas of screens, not a strip of items"
        ),
    ]

    @Test("a sideways scroll view lives in the container")
    func oneScroller() throws {
        var holders: [String: Int] = [:]
        for (name, source) in try Self.settingsSources() {
            for tail in source.components(separatedBy: "ScrollView(")
                .dropFirst()
            where !tail.hasPrefix(".vertical")
                && !tail.hasPrefix("showsIndicators:")
                && !tail.hasPrefix(")")
            {
                holders[name, default: 0] += 1
            }
        }
        #expect(holders == Self.allowed.mapValues(\.count))
    }

    /// Core's arithmetic is reached through the run alone, so a strip
    /// cannot fade or follow by a reading of its own.
    @Test("only the run calls Core's fade and follow")
    func oneArithmetic() throws {
        var callers: Set<String> = []
        for (name, source) in try Self.settingsSources()
        where source.contains("ShelfOverflow.fades(")
            || source.contains("ShelfOverflow.offset(")
        {
            callers.insert(name)
        }
        #expect(callers == ["StripRun.swift"])
    }

    @Test("the container owns its scroll and draws the run's fade")
    func containerWiring() throws {
        let strip = try Self.squashed(
            "Components/Common/SidewaysStrip.swift"
        )
        #expect(strip.contains("@Stateprivatevarscroll=StripScroll()"))
        #expect(strip.contains(".mask(StripFade(fades:run.fades(scroll)))"))
        // The offset reads the run's leading edge in the scroller's
        // own space, negated: a dropped sign never fades the lead.
        #expect(strip.contains("-$0.frame(in:.named(stripSpace)).minX"))
        #expect(strip.contains(".coordinateSpace(.named(stripSpace))"))
        #expect(strip.contains("action:{scroll.offset=$0}"))
        #expect(strip.contains("action:{scroll.viewport=$0}"))
        #expect(strip.contains(".onChange(of:followed){_,itemin"))
        #expect(
            strip.contains(
                "run.followAnchor(index:item.index,scroll:scroll)"
            )
        )
        #expect(strip.contains("proxy.scrollTo(item.id,anchor:anchor)"))
    }

    @Test("the run counts its gaps and end room and answers Core's fades")
    func runArithmetic() {
        let bare = StripRun(lengths: [100, 100, 100], gap: 10, depth: 60)
        #expect(bare.total == 320)
        let roomy = StripRun(
            lengths: [100, 100, 100],
            gap: 10,
            depth: 60,
            endRoom: 4
        )
        #expect(roomy.total == 328)
        let core = ShelfOverflow.fades(
            lengths: [100, 100, 100],
            gap: 10,
            total: 320,
            offset: 0,
            viewport: 200,
            depth: 60
        )
        #expect(bare.fades(StripScroll(offset: 0, viewport: 200)) == core)
        #expect(core.trailing > 0)
    }

    /// The end room stays in view on a follow to the first item, and a
    /// later item starts past its gaps.
    @Test("the follow anchor counts the end room and the gaps")
    func followStart() throws {
        let run = StripRun(lengths: [100, 100, 100, 100], gap: 10, depth: 60)
        let end = StripScroll(offset: run.total - 200, viewport: 200)
        let first = try #require(run.followAnchor(index: 0, scroll: end))
        #expect(first.x == 0)
        let roomy = StripRun(
            lengths: [100, 100, 100, 100],
            gap: 10,
            depth: 60,
            endRoom: 4
        )
        let shifted = try #require(
            roomy.followAnchor(
                index: 0,
                scroll: StripScroll(offset: roomy.total - 200, viewport: 200)
            )
        )
        #expect(abs(shifted.x * 100 - 4) < 0.01)
        let rest = StripScroll(offset: 0, viewport: 200)
        #expect(run.followAnchor(index: 0, scroll: rest) == nil)
        #expect(run.followAnchor(index: 3, scroll: rest) != nil)
        #expect(run.followAnchor(index: 9, scroll: rest) == nil)
    }

    private static func look(_ name: String) -> ShelfLook {
        ShelfLook(name: name, style: [:], colors: [:])
    }

    @Test("the look line's run measures what it draws, in order")
    @MainActor func lookRun() {
        let entries = SimpleLookCard.entries(
            mine: [Self.look("Mine")],
            bundled: [Self.look("Default"), Self.look("Mine")]
        )
        #expect(
            entries.map(\.id) == [
                "mine:Mine", "hairline", "bundled:Default", "bundled:Mine",
                "browse",
            ]
        )
        let tile = SimpleLookCard.tileWidth
        #expect(
            SimpleLookCard.run(entries: entries).lengths
                == [tile, SimpleLookCard.hairline, tile, tile, tile]
        )
        // No looks of the user's, no hairline.
        #expect(
            SimpleLookCard.entries(mine: [], bundled: [Self.look("Default")])
                .map(\.id) == ["bundled:Default", "browse"]
        )
    }

    /// A fade only where it cuts a tile: none at the scroll's end, the
    /// static fade this replaced.
    @Test("the look line fades only an end that cuts a tile")
    @MainActor func lookFades() {
        let run = SimpleLookCard.run(
            entries: SimpleLookCard.entries(
                mine: [],
                bundled: (0..<8).map { Self.look("Look \($0)") }
            )
        )
        let viewport: CGFloat = 400
        let rest = run.fades(StripScroll(offset: 0, viewport: viewport))
        #expect(rest.leading == 0 && rest.trailing > 0)
        let end = run.fades(
            StripScroll(offset: run.total - viewport, viewport: viewport)
        )
        #expect(end.leading > 0 && end.trailing == 0)
    }

    /// The line draws the same list the run measures.
    @Test("the look line takes the container and draws its entries")
    func lookWiring() throws {
        let card = try Self.squashed(
            "Components/Simple/SimpleLookCard.swift"
        )
        #expect(card.contains("ViewThatFits(in:.horizontal)"))
        #expect(
            card.contains(
                "SidewaysStrip(run:Self.run(entries:entries),"
                    + "followed:followed(in:entries))"
            )
        )
        #expect(card.contains("ForEach(entries){entryin"))
        #expect(card.contains("view(for:entry).id(entry.id)"))
        #expect(card.contains(".focused($focusedTile,equals:look.name)"))
        #expect(card.contains(".focused($focusedTile,equals:browseFocus)"))
        #expect(card.contains("StripFollow(id:entries[index].id,index:index)"))
        // One read of the bundled looks per render (the catalog
        // decodes from disk), and none of a scroll tick's.
        #expect(card.components(separatedBy: "bundledLooks").count == 3)
        #expect(!card.contains("LinearGradient"))
    }
}
