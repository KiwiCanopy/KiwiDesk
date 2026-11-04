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

    /// Who may hold a sideways scroll view: the container, and the
    /// Spaces chips, whose widths vary, so a `StripRun` needs measured
    /// lengths first.
    private static let allowed: Set<String> = [
        "SidewaysStrip.swift", "SpacesPanelPreview.swift",
    ]

    @Test("a sideways scroll view lives in the container")
    func oneScroller() throws {
        let files = try SourceScan.swiftSources(
            under: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(Self.root)
        )
        var holders: Set<String> = []
        for url in files {
            let source = try Self.squashed(url)
            if source.contains("ScrollView(.horizontal") {
                holders.insert(url.lastPathComponent)
            }
        }
        #expect(holders == Self.allowed)
    }

    @Test("the container measures its scroll and draws the fade")
    func containerWiring() throws {
        let strip = try Self.squashed(
            "Components/Common/SidewaysStrip.swift"
        )
        #expect(strip.contains(".mask(StripFade(fades:fades))"))
        // The offset reads the run's leading edge in the scroller's
        // own space, negated: a dropped sign never fades the lead.
        #expect(strip.contains("-$0.frame(in:.named(Self.space)).minX"))
        #expect(strip.contains(".coordinateSpace(.named(Self.space))"))
        #expect(strip.contains("action:{scroll.offset=$0}"))
        #expect(strip.contains("action:{scroll.viewport=$0}"))
    }

    @Test("the run adds its gaps and answers Core's fades")
    func runArithmetic() {
        let run = StripRun(lengths: [100, 100, 100], gap: 10, depth: 60)
        #expect(run.total == 320)
        let scroll = StripScroll(offset: 0, viewport: 200)
        let core = ShelfOverflow.fades(
            lengths: run.lengths,
            gap: 10,
            total: 320,
            offset: 0,
            viewport: 200,
            depth: 60
        )
        #expect(run.fades(scroll) == core)
        #expect(core.trailing > 0)
    }

    /// The inset is room before the first item, so a follow onto it
    /// leaves that room in view; a later item starts past its gaps.
    @Test("the follow anchor counts the inset and the gaps")
    func followStart() throws {
        let run = StripRun(lengths: [104, 100, 100, 100], gap: 10, depth: 60)
        let end = StripScroll(offset: run.total - 200, viewport: 200)
        let first = try #require(
            run.followAnchor(index: 0, width: 100, scroll: end)
        )
        #expect(first.x == 0)
        let inset = StripRun(
            lengths: [104, 100, 100, 100],
            gap: 10,
            depth: 60,
            inset: 4
        )
        let shifted = try #require(
            inset.followAnchor(index: 0, width: 100, scroll: end)
        )
        #expect(shifted.x > 0)
        let rest = StripScroll(offset: 0, viewport: 200)
        #expect(run.followAnchor(index: 0, width: 100, scroll: rest) == nil)
        #expect(run.followAnchor(index: 3, width: 100, scroll: rest) != nil)
    }

    @Test("the look line's run holds every tile and the hairline")
    @MainActor func lookRun() {
        let entries = SimpleLookCard.entries(
            mine: ["Mine"],
            bundled: ["Default", "Glass"]
        )
        let browse = SimpleLookCard.browseID
        #expect(entries == ["Mine", "", "Default", "Glass", browse])
        let tile = SimpleLookCard.tileWidth
        let run = SimpleLookCard.run(entries: entries)
        #expect(
            run.lengths == [tile, SimpleLookCard.hairline, tile, tile, tile]
        )
        // No looks of the user's, no hairline.
        #expect(
            SimpleLookCard.entries(mine: [], bundled: ["Default"])
                == ["Default", browse]
        )
    }

    /// A fade only where it cuts a tile: none at the scroll's end, the
    /// static fade this replaced.
    @Test("the look line fades only an end that cuts a tile")
    @MainActor func lookFades() {
        let names = (0..<8).map { "Look \($0)" }
        let run = SimpleLookCard.run(
            entries: SimpleLookCard.entries(mine: [], bundled: names)
        )
        let viewport: CGFloat = 400
        let rest = run.fades(StripScroll(offset: 0, viewport: viewport))
        #expect(rest.leading == 0 && rest.trailing > 0)
        let end = run.fades(
            StripScroll(offset: run.total - viewport, viewport: viewport)
        )
        #expect(end.leading > 0 && end.trailing == 0)
    }

    @Test("the look line takes the container and follows every tile")
    func lookWiring() throws {
        let card = try Self.squashed(
            "Components/Simple/SimpleLookCard.swift"
        )
        #expect(card.contains("ViewThatFits(in:.horizontal)"))
        #expect(
            card.contains(
                "SidewaysStrip(scroll:$scroll,fades:run.fades(scroll))"
            )
        )
        #expect(card.contains("follow(id,with:proxy)"))
        #expect(card.contains("proxy.scrollTo(id,anchor:anchor)"))
        #expect(card.contains(".id(look.name)"))
        #expect(card.contains(".focused($focusedTile,equals:Self.browseID)"))
        #expect(card.contains(".id(Self.browseID)"))
        #expect(!card.contains("LinearGradient"))
    }
}
