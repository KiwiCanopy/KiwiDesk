import Foundation
import Testing

/// Every raw `.maximized` spelling in `KiwiDeskCore` (#2448). The
/// stored `Space.maximized` is the toggle's intent; whether a
/// window IS maximized is the one verdict,
/// `StateCoordinator.maximizedWindow(of:)`, because the stored id
/// outlives a focus that ended it until the retire runs. So a
/// reader beside a call site reds here until it routes through the
/// verdict or names its reason below — a writer that ends the
/// maximize at a rearranging write included.
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
        // The in-place carry, written and adopted.
        "Models/StateSnapshot+InPlace.swift": 3,
        // The verdict, the retire and the profile-switch end.
        "State/StateCoordinator+Maximized.swift": 5,
        // A Desktop departure records it; the return pays it.
        "State/StateCoordinator+SpaceMemory.swift": 2,
        "State/StateCoordinator+WindowCreated.swift": 3,
        // The mode write ends it.
        "State/WorkspaceManager.swift": 1,
        // The toggle and the drag's end.
        "App/KiwiCore+Maximize.swift": 5,
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
        let pattern = try NSRegularExpression(
            pattern: "\\.maximized\\b"
        )
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
