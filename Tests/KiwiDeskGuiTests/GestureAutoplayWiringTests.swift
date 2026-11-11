import Foundation
import Testing

@testable import KiwiDesk

/// A gesture picture plays by itself once per visit, on the user's
/// own click alone: the part's first entry when a click on the
/// Mouse & Trackpad segment opens it (owner ruling 2026-09-29,
/// carried to the segment by #3184; gui.md ▸ "A gesture picture is
/// not a schematic"). A search, Go to or diff jump lands on the
/// part through `nav` and arms nothing.
@Suite("Gesture autoplay wiring (#1726)")
struct GestureAutoplayWiringTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static func squashed(_ url: URL) throws -> String {
        SourceScan.stripComments(try String(contentsOf: url, encoding: .utf8))
            .split(whereSeparator: \.isWhitespace).joined()
    }

    private static func squashed(_ file: String) throws -> String {
        try squashed(root.appendingPathComponent(file))
    }

    /// Only the item initializer hands an entry its play, and only
    /// while the drawer's `playing` names that item.
    @Test("an entry plays only while `playing` names it")
    func oneHost() throws {
        let files = try SourceScan.swiftSources(under: Self.root)
        #expect(files.count > 50)
        var found: Set<String> = []
        for url in files
        where try Self.squashed(url).contains("playsOnAppear:") {
            found.insert(url.lastPathComponent)
        }
        // The declaring file spells the label in its init.
        #expect(found == ["GestureEntry.swift", "GestureEntry+Item.swift"])
        let item = try Self.squashed(
            "Settings/Components/Gestures/GestureEntry+Item.swift"
        )
        #expect(item.contains("get:{playing.wrappedValue==item}"))
    }

    /// Armed only by the segment's own pick, once per visit through
    /// `gesturesPlayed`; spent by the part on its appear, so a
    /// search landing or a re-mount rests.
    @Test("the part plays once per visit, on a click")
    func oncePerVisit() throws {
        let segment = try Self.squashed(
            "Settings/Sections/ShortcutsSection+Segment.swift"
        )
        let pick = try #require(
            SourceScan.declarationBody(
                after: "privatefuncsegmentBinding(",
                in: segment
            )
        )
        // Across every file of the page: the declaration and the
        // pick's one arming write; and nothing else in Settings arms
        // the part's binding.
        let page = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Settings/Sections")
        ).filter { $0.lastPathComponent.hasPrefix("ShortcutsSection") }
        #expect(page.count >= 4)
        let writes = try page.map {
            try Self.squashed($0).components(separatedBy: "gesturesPlay=")
                .count - 1
        }.reduce(0, +)
        #expect(writes == 2)
        #expect(segment.components(separatedBy: "gesturesPlay=").count == 2)
        let settings = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Settings")
        )
        #expect(settings.count > 50)
        for url in settings {
            #expect(
                !(try Self.squashed(url).contains("playArmed=true")),
                Comment(rawValue: url.lastPathComponent)
            )
        }
        #expect(
            pick.contains(
                "ifpicked==.mouse,!gesturesPlayed{gesturesPlayed=true"
                    + "gesturesPlay=true}"
            )
        )
        let part = try Self.squashed(
            "Settings/Components/Gestures/GesturesPart.swift"
        )
        let appear = try #require(
            SourceScan.declarationBody(after: ".onAppear", in: part)
        )
        // Spent before it plays, and only while armed.
        #expect(appear.hasPrefix("guardplayArmedelse{return}"))
        let spent = try #require(appear.range(of: "playArmed=false"))
        let plays = try #require(
            appear.range(of: "playing=GestureItem.allCases.first")
        )
        #expect(spent.lowerBound < plays.lowerBound)
        // The entry spends its own flag before it plays.
        let entry = try Self.squashed(
            "Settings/Components/Gestures/GestureEntry.swift"
        )
        let entryAppear = try #require(
            SourceScan.declarationBody(after: ".onAppear", in: entry)
        )
        #expect(entryAppear.hasPrefix("guardplaysOnAppearelse{return}"))
        let entrySpent = try #require(
            entryAppear.range(of: "playsOnAppear=false")
        )
        let entryPlays = try #require(entryAppear.range(of: "autoplay()"))
        #expect(entrySpent.lowerBound < entryPlays.lowerBound)
    }

    /// Reduce Motion: the run is refused before it starts, and the
    /// animation names its gate (`ReduceMotionGateTests` holds the
    /// argument; this holds the early return).
    @Test("autoplay stands down under Reduce Motion")
    func reduceMotion() throws {
        let entry = try Self.squashed(
            "Settings/Components/Gestures/GestureEntry.swift"
        )
        let body = try #require(
            SourceScan.declarationBody(
                after: "privatefuncautoplay(",
                in: entry
            )
        )
        #expect(body.hasPrefix("guard!reduceMotionelse{return}"))
        #expect(
            body.contains("withAnimation(reduceMotion?nil:pace.animation)")
        )
        #expect(!body.contains("repeatForever"))
    }

    /// The click is the only trigger tree-wide: nothing in the
    /// part's files writes `playing` but the part's one arming site
    /// and the item initializer's spend, so an entry file cannot
    /// start a play on its own appear.
    @Test("only the part arms a play; only the entry spends it")
    func playWriters() throws {
        let allowed: [String: Int] = [
            "GesturesPart.swift": 1,
            "GestureEntry+Item.swift": 1,
        ]
        let dir = Self.root.appendingPathComponent(
            "Settings/Components/Gestures"
        )
        let files = try SourceScan.swiftSources(under: dir)
        #expect(files.count > 10)
        var found: [String: Int] = [:]
        for url in files {
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            // An assignment to `playing` itself, never a comparison's
            // `==` nor another name ending in it (`autoplaying`).
            let count = source.matches(
                of: try Regex(#"\bplaying(\.wrappedValue)?\s*=(?!=)"#)
            ).count
            if count > 0 { found[url.lastPathComponent] = count }
        }
        #expect(found == allowed)
    }
}
