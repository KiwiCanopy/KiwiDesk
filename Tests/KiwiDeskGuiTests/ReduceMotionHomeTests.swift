import Foundation
import Testing

/// KiwiDesk's own Off joins macOS Reduce Motion in one read in Core
/// (#3238): `ReduceMotion.isOn`. A second AppKit read of the OS flag
/// there plays motion while the preset says Off, so that spelling
/// lives in `ReduceMotion.swift` alone. The scan stops at Core, as
/// the ruling does: the GUI tree's panels (KiwiHub, the cue plates,
/// the boot notice) and Settings read macOS's setting alone, through
/// AppKit or SwiftUI's `\.accessibilityReduceMotion`, and are not
/// scanned.
@Suite("Reduce Motion home (#3238)")
struct ReduceMotionHomeTests {
    private static let needle = "accessibilityDisplayShouldReduceMotion"
    private static let home = "ReduceMotion.swift"

    @Test("only the home reads the OS flag in Core")
    func oneRead() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var found: [String: Int] = [:]
        for tree in ["Sources/KiwiDeskCore"] {
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

    /// A gate reading the home's OS half drops KiwiDesk's Off as
    /// surely as an `NSWorkspace` read, so no file in either tree
    /// names `ReduceMotion.system`; the home spells it bare.
    @Test("no gate reads the home's OS half")
    func noSystemHalf() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        var found: [String] = []
        for tree in ["Sources/KiwiDeskCore", "Sources/KiwiDesk"] {
            let files = try SourceScan.swiftSources(
                under: root.appendingPathComponent(tree)
            )
            #expect(!files.isEmpty, "\(tree)")
            for file in files
            where try SourceScan.strippedSource(at: file)
                .filter({ !$0.isWhitespace })
                .contains("ReduceMotion.system")
            {
                found.append(file.lastPathComponent)
            }
        }
        #expect(found.isEmpty, "\(found)")
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
