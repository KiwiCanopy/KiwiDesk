import Foundation
import Testing

/// Every raw `.maximized` spelling in `KiwiDeskCore` (#2448). The
/// stored `Space.maximized` is the toggle's intent; whether a
/// window IS maximized is the one verdict,
/// `StateCoordinator.maximizedWindow(of:)`, because the stored id
/// outlives a focus that ended it until the retire runs. So a
/// reader beside a call site reds here until it routes through the
/// verdict or names its reason below — a writer that ends the
/// maximize at a rearranging write included. Blind spot: a bare
/// `maximized` inside a `Space` extension (the model's own
/// primitives) has no dot and is not counted.
@Suite("Maximized reader census (#2448)")
struct MaximizedReaderCensusTests {
    private var coreRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Every file that may spell `.maximized`, by path under
    /// `Sources/KiwiDeskCore`, with its count and its reason. This
    /// map is the one copy of who may.
    private let allowed: [String: Int] = [
        // The model's initializer; `remove`, the rekey and the
        // reorder release write the field bare, inside the type.
        "Models/SpaceModel.swift": 1,
        // The in-place carry of the window, its shape (#3062) and its
        // follow (#3063), written and adopted.
        "Models/StateSnapshot+InPlace.swift": 5,
        // The verdict, its shape, the follow, and the retire, which
        // ends or re-points it and names the windows (#2676, #3063);
        // a float's plane and the return frames no Maximize holds
        // (#3036).
        "State/StateCoordinator+Maximized.swift": 9,
        // A close while away and a minimize end it; a Desktop
        // departure keeps the id for the return.
        "State/StateCoordinator+SpaceMemory.swift": 2,
        "State/StateCoordinator+WindowDestroyed.swift": 2,
        // The mode write ends it; a re-key reaches a traveler's flag
        // on a Space it is no member of (#3035).
        "State/WorkspaceManager.swift": 3,
        // The toggle, its shape change, and the drag's end; a pocket
        // take-out lands plain beside any stored Maximize and writes
        // its own (#3408).
        "App/KiwiCore+Maximize.swift": 9,
        // Rearranging writes end it.
        "Commands/KiwiCore+Resize.swift": 2,
        "Commands/KiwiCore+ResetLayoutSizing.swift": 1,
    ]

    /// A maximize reads the bars Hidden through the shelf's one
    /// settings door, never the stand-down (#3346): the door asks
    /// the maximize, and the stand-down asks only the covered half.
    @Test("The shelf's settings door asks the maximize")
    func shelfAsksTheMaximize() throws {
        let edges = try SourceScan.strippedSource(
            at: coreRoot.appendingPathComponent(
                "App/KiwiCore+ScreenEdges.swift"
            )
        )
        let door = try #require(
            SourceScan.declarationBody(
                after: "func shelfSettings(on display: DisplayID)",
                in: edges
            )
        )
        #expect(door.contains("screenMaximizes(on: display)"))
        let covering = try SourceScan.strippedSource(
            at: coreRoot.appendingPathComponent(
                "App/KiwiCore+ScreenCovering.swift"
            )
        )
        let standDown = try #require(
            SourceScan.declarationBody(
                after: "func shelfStandsDown(on display: DisplayID)",
                in: covering
            )
        )
        #expect(standDown.contains("overlaysStandDown(on: display)"))
        #expect(!standDown.contains("showsMaximized("))
        #expect(!standDown.contains("screenMaximizes("))
    }

    @Test("Only the allowlisted files spell the stored maximize")
    func readersAreCensused() throws {
        try census("\\.maximized\\b", allowed)
    }

    private func census(
        _ needle: String,
        _ allowed: [String: Int]
    ) throws {
        let pattern = try NSRegularExpression(pattern: needle)
        var counts: [String: Int] = [:]
        let prefix = coreRoot.path + "/"
        for file in try SourceScan.swiftSources(under: coreRoot) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let hits = pattern.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            guard hits > 0 else { continue }
            counts[String(file.path.dropFirst(prefix.count))] = hits
        }
        #expect(!counts.isEmpty, "the scan read no source")
        #expect(
            counts == allowed,
            "found: \(counts)"
        )
    }
}
