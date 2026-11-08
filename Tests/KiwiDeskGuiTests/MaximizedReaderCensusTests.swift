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
        // The in-place carry of the window and its shape (#3062),
        // written and adopted.
        "Models/StateSnapshot+InPlace.swift": 4,
        // The verdict, its shape, and the retire, which names the
        // windows it ended (#2676).
        "State/StateCoordinator+Maximized.swift": 5,
        // A close while away and a minimize end it; a Desktop
        // departure keeps the id for the return.
        "State/StateCoordinator+SpaceMemory.swift": 2,
        "State/StateCoordinator+WindowDestroyed.swift": 2,
        // The mode write ends it; a re-key reaches a traveler's flag
        // on a Space it is no member of (#3035).
        "State/WorkspaceManager.swift": 3,
        // The toggle, its shape change, and the drag's end.
        "App/KiwiCore+Maximize.swift": 7,
        // Rearranging writes end it.
        "Commands/KiwiCore+Resize.swift": 2,
        "Commands/KiwiCore+ResetLayoutSizing.swift": 1,
    ]

    /// The shelf's one stand-down door asks the maximize arm —
    /// once, since the door's native-fullscreen read is live and no
    /// fixture can drive the door itself.
    @Test("The shelf stand-down asks the maximize")
    func shelfAsksTheMaximize() throws {
        let file = coreRoot.appendingPathComponent(
            "App/KiwiCore+ScreenCovering.swift"
        )
        let source = SourceScan.stripComments(
            try String(contentsOf: file, encoding: .utf8)
        )
        #expect(
            source.components(
                separatedBy: "|| showsMaximized(on: display)"
            ).count == 2
        )
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
