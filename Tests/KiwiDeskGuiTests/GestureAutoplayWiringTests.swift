import Foundation
import Testing

@testable import KiwiDesk

/// A gesture picture plays by itself once, and only the card's
/// first entry, only on the user's own click open (owner ruling
/// 2026-09-29, gui.md ▸ "A gesture picture is not a schematic").
/// A search, Go to or diff jump expands the card through
/// `SettingsCollapsibleSection.expand(revealing:)`, which must
/// never reach `onToggle`.
@Suite("Gesture autoplay wiring (#1726)")
struct GestureAutoplayWiringTests {
    /// The one copy of who may ask an entry to play on appear.
    static let hosts: [String: String] = [
        "Settings/Components/Gestures/GesturesScrollEntries.swift":
            "the ⌃⌥ entry, the card's first"
    ]

    private static let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDesk")

    private static func squashed(_ url: URL) throws -> String {
        SourceScan.stripComments(try String(contentsOf: url, encoding: .utf8))
            .split(whereSeparator: \.isWhitespace).joined()
    }

    private static func squashed(_ file: String) throws -> String {
        try squashed(root.appendingPathComponent(file))
    }

    @Test("only the card's first entry plays on appear")
    func oneHost() throws {
        let files = try SourceScan.swiftSources(under: Self.root)
        #expect(files.count > 50)
        var found: [String: Int] = [:]
        for url in files {
            let count =
                try Self.squashed(url)
                .components(separatedBy: "playsOnAppear:").count - 1
            let file = String(url.path.dropFirst(Self.root.path.count + 1))
            // The declaring file spells the label in its init.
            if count > 0, !file.hasSuffix("GestureEntry.swift") {
                found[file] = count
            }
        }
        #expect(found == Self.hosts.mapValues { _ in 1 })
        let entries = try Self.squashed(
            "Settings/Components/Gestures/GesturesScrollEntries.swift"
        )
        let body = try #require(entries.range(of: "varbody:someView{"))
        let first = try #require(
            entries.range(
                of: "GestureEntry(",
                range: body.upperBound..<entries.endIndex
            )
        )
        let plays = try #require(entries.range(of: "playsOnAppear:$autoplay"))
        let second = try #require(
            entries.range(
                of: "GestureEntry(",
                range: first.upperBound..<entries.endIndex
            )
        )
        // Handed to the body's FIRST entry, not a later one.
        #expect(first.upperBound < plays.lowerBound)
        #expect(plays.lowerBound < second.lowerBound)
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

    /// Per visit: armed only inside the click hook, gated on the
    /// visit's `played`, and spent by the entry that plays — so a
    /// search open, a second click or a re-mount rests.
    @Test("the drawer plays once per visit, on the click")
    func oncePerVisit() throws {
        let drawer = try Self.squashed(
            "Settings/Components/Gestures/GesturesDrawer.swift"
        )
        let hook = try #require(
            SourceScan.declarationBody(after: "onToggle:", in: drawer)
        )
        // One arming site besides the declaration, inside the hook
        // and read against `played`.
        #expect(drawer.components(separatedBy: "autoplay=").count == 3)
        #expect(hook.contains("autoplay="))
        #expect(hook.contains("!played"))
        #expect(drawer.components(separatedBy: "played=true").count == 2)
        #expect(hook.contains("played=true"))
        #expect(drawer.contains("autoplay:$autoplay"))
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
}
