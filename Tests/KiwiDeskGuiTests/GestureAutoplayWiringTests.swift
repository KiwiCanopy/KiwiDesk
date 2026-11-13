import Foundation
import Testing

@testable import KiwiDesk

/// A gesture picture moves only while hovered (#1726; #3281
/// retired the first-visit play; gui.md ▸ "A gesture picture is
/// not a schematic"): the picture's state is written on hover
/// alone, nothing in the part animates or starts on its own, and
/// the retired play's names stay out.
@Suite("Gesture autoplay stays retired (#3281)")
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

    /// The entry moves on hover alone: its picture's state is
    /// written only inside `hover(`, besides the declarations.
    @Test("an entry moves only while hovered")
    func hoverOnly() throws {
        let entry = try Self.squashed(
            "Settings/Components/Gestures/GestureEntry.swift"
        )
        #expect(entry.contains(".onHover(perform:hover)"))
        let hover = try #require(
            SourceScan.declarationBody(
                after: "privatefunchover(",
                in: entry
            )
        )
        for (write, declared) in [
            ("phase=", "privatevarphase:CGFloat=0"),
            ("hovering=", "privatevarhovering=false"),
        ] {
            #expect(entry.contains(declared), "\(declared)")
            let all = entry.components(separatedBy: write).count - 1
            let inside = hover.components(separatedBy: write).count - 1
            // The declaration spells `hovering=`; `phase`'s spells
            // `:CGFloat=` and counts no write.
            let declarations = write == "hovering=" ? 1 : 0
            #expect(inside > 0, "\(write)")
            #expect(all == inside + declarations, "\(write)")
        }
    }

    /// Only the entry animates in the gestures part, and none of the
    /// part's picture files starts anything as it appears or changes.
    @Test("nothing animates or plays on its own")
    func noSelfStart() throws {
        let dir = Self.root.appendingPathComponent(
            "Settings/Components/Gestures"
        )
        let files = try SourceScan.swiftSources(under: dir)
        #expect(files.count > 10)
        for url in files {
            let source = try Self.squashed(url)
            let animates = ["withAnimation", "repeatForever", "TimelineView"]
                .contains { source.contains($0) }
            #expect(
                !animates || url.lastPathComponent == "GestureEntry.swift",
                Comment(rawValue: url.lastPathComponent)
            )
        }
        for file in [
            "GestureEntry.swift", "GestureEntry+Item.swift",
            "GesturesPart.swift", "GesturesScrollEntries.swift",
            "GesturesShelfEntries.swift",
        ] {
            let source = try Self.squashed(
                "Settings/Components/Gestures/" + file
            )
            for needle in [".onAppear", ".task{", ".task(", ".onChange("] {
                #expect(
                    !source.contains(needle),
                    Comment(rawValue: "\(file): \(needle)")
                )
            }
        }
    }

    /// No file of the gestures part or the Shortcuts page carries
    /// the retired play's plumbing back.
    @Test("nothing arms a play")
    func noArming() throws {
        let gestures = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent(
                "Settings/Components/Gestures"
            )
        )
        let page = try SourceScan.swiftSources(
            under: Self.root.appendingPathComponent("Settings/Sections")
        ).filter { $0.lastPathComponent.hasPrefix("ShortcutsSection") }
        #expect(gestures.count > 10)
        #expect(page.count >= 4)
        for url in gestures + page {
            let source = try Self.squashed(url)
            for needle in [
                "playsOnAppear", "autoplay", "playArmed", "gesturesPlay",
                "playing:",
            ] {
                #expect(
                    !source.contains(needle),
                    Comment(rawValue: "\(url.lastPathComponent): \(needle)")
                )
            }
        }
    }
}
