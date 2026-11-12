import Foundation
import Testing

/// KiwiDesk's own Off joins macOS Reduce Motion in one read (#3238):
/// `ReduceMotion.isOn`. A second AppKit read of the OS flag plays
/// motion while the preset says Off, so the OS spelling lives in
/// `ReduceMotion.swift` alone, in both trees. SwiftUI's
/// `\.accessibilityReduceMotion` is a separate spelling, read by
/// Settings' own views for their own motion, and is not scanned.
@Suite("Reduce Motion home (#3238)")
struct ReduceMotionHomeTests {
    private static let needle = "accessibilityDisplayShouldReduceMotion"
    private static let home = "ReduceMotion.swift"

    @Test("only the home reads the OS flag")
    func oneRead() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var found: [String: Int] = [:]
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty, "\(tree)")
            for file in files {
                let count = try SourceScan.strippedSource(at: file)
                    .occurrences(of: Self.needle)
                if count > 0 { found[file.lastPathComponent] = count }
            }
        }
        #expect(found == [Self.home: 1])
    }

    /// The home joins both reads, so a gate asking it sees the
    /// preset's Off as well as macOS's.
    @Test("the home ORs KiwiDesk's Off into the OS read")
    func homeJoinsBoth() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let url = root.appendingPathComponent(
            "Sources/KiwiDeskCore/Animation/" + Self.home
        )
        let source = try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
        #expect(
            source.contains(
                "publicstaticvarisOn:Bool{system||kiwiDesk}"
            )
        )
    }

    /// The gates that once read the OS flag read the home now: the
    /// window engine, the bars' gate the overlays default to, and
    /// the flag's one writer, the live app-wide change.
    @Test("the gates and the flag's writer are wired")
    func gatesAreWired() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        let needles = [
            "App/KiwiCore+Bootstrap.swift":
                "tiler.animation.reduceMotion={ReduceMotion.isOn}",
            "Bar/BarMotion.swift": "returnReduceMotion.isOn",
            "App/KiwiCore+AppWideLive.swift":
                "ReduceMotion.kiwiDesk=new.animationReduceMotion",
        ]
        for (path, needle) in needles {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            ).filter { !$0.isWhitespace }
            #expect(source.contains(needle), "\(path)")
        }
    }
}
