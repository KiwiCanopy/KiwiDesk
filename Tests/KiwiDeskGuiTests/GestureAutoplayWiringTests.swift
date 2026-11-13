import Foundation
import Testing

@testable import KiwiDesk

/// A gesture picture moves only while hovered (#1726; #3281
/// retired the first-visit play; gui.md ▸ "A gesture picture is
/// not a schematic"): no entry plays on appear, and nothing in
/// the part or the page arms a play.
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

    /// The entry moves on hover alone: nothing it does on appear,
    /// and its one moving state is the hover.
    @Test("an entry moves only while hovered")
    func hoverOnly() throws {
        let entry = try Self.squashed(
            "Settings/Components/Gestures/GestureEntry.swift"
        )
        #expect(entry.contains(".onHover(perform:hover)"))
        #expect(!entry.contains(".onAppear"))
        #expect(!entry.contains(".task"))
        #expect(entry.contains("privatevarmoving:Bool{hovering}"))
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
