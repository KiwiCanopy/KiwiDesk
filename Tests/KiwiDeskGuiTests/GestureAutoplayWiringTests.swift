import Foundation
import Testing

@testable import KiwiDesk

/// A gesture picture plays by itself once per visit, on the user's
/// own click alone: the card's first entry on a click open (owner
/// ruling 2026-09-29), or the entry a click on its picture in the
/// shut card's strip lands on (owner ruling 2026-10-17; gui.md ▸
/// "A gesture picture is not a schematic"). A search, Go to or
/// diff jump expands the card through
/// `SettingsCollapsibleSection.expand(revealing:)`, which must
/// never reach `onToggle`.
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

    @Test("only the disclosure's own click reaches onToggle")
    func clickOnly() throws {
        let file =
            "Settings/Components/Common/"
            + "SettingsCollapsibleSection.swift"
        let source = try Self.squashed(file)
        #expect(
            source.contains(
                "SettingsDisclosureButton(isExpanded:clicked,"
            )
        )
        #expect(source.components(separatedBy: "onToggle?(").count == 2)
        let clicked = try #require(
            SourceScan.declarationBody(
                after: "privatevarclicked:Binding<Bool>",
                in: source
            )
        )
        #expect(clicked.contains("onToggle?(open)"))
        let expand = try #require(
            SourceScan.declarationBody(
                after: "privatefuncexpand(",
                in: source
            )
        )
        #expect(!expand.contains("onToggle"))
        // Nor one hop away: only the disclosure writes `clicked`.
        #expect(!expand.contains("clicked"))
        #expect(source.components(separatedBy: "clicked").count == 3)
    }

    /// Armed only by a click: the open's hook, once per visit
    /// through `played`, or a strip picture's land, once per such
    /// click; spent by the entry that plays, so a search open or a
    /// re-mount rests.
    @Test("the drawer plays once per visit, on a click")
    func oncePerVisit() throws {
        let drawer = try Self.squashed(
            "Settings/Components/Gestures/GesturesDrawer.swift"
        )
        let hook = try #require(
            SourceScan.declarationBody(after: "onToggle:", in: drawer)
        )
        let land = try #require(
            SourceScan.declarationBody(
                after: "privatevarstrip:someView",
                in: drawer
            )
        )
        // Two arming sites besides the declaration: the hook, read
        // against `played`, and the land, which spends the visit.
        #expect(drawer.components(separatedBy: "playing=").count == 3)
        #expect(hook.contains("ifopen,!played{playing=.scrollStep}"))
        #expect(land.contains("playing=item"))
        #expect(drawer.components(separatedBy: "played=true").count == 3)
        #expect(hook.contains("played=true"))
        #expect(land.contains("played=true"))
        // The entry spends the flag before it plays.
        let entry = try Self.squashed(
            "Settings/Components/Gestures/GestureEntry.swift"
        )
        let appear = try #require(
            SourceScan.declarationBody(after: ".onAppear", in: entry)
        )
        // Plays only while armed: the read gates the whole body.
        #expect(appear.hasPrefix("guardplaysOnAppearelse{return}"))
        let spent = try #require(appear.range(of: "playsOnAppear=false"))
        let plays = try #require(appear.range(of: "autoplay()"))
        #expect(spent.lowerBound < plays.lowerBound)
    }

    /// A strip picture moves only while hovered and never under
    /// Reduce Motion: the hover is refused there, and the loop
    /// names its gate.
    @Test("a strip picture's hover loop stands down under Reduce Motion")
    func stripReduceMotion() throws {
        let plate = try Self.squashed(
            "Settings/Components/Gestures/GestureStripPlate.swift"
        )
        #expect(plate.contains("hovering=inside&&!reduceMotion"))
        #expect(
            plate.contains(
                "withAnimation(reduceMotion?nil:item.pace.animation"
                    + ".repeatForever("
            )
        )
        #expect(plate.contains("item.picture(t:hovering?phase:1,"))
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
    /// card's files writes `playing` but the drawer's two arming
    /// sites and the item initializer's spend, so an entry file
    /// cannot start a play on its own appear.
    @Test("only the drawer arms a play; only the entry spends it")
    func playWriters() throws {
        let allowed: [String: Int] = [
            "GesturesDrawer.swift": 2,
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
