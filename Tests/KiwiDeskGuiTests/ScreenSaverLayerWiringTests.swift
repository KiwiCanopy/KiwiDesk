import Foundation
import Testing

/// The #2069 level refuses adoption only: `track` judges as
/// untracked, the reconcile asks state, so a tracked window that
/// rises to the level is never swept as a close.
@Suite("Screen-saver level wiring (#2069)")
struct ScreenSaverLayerWiringTests {
    private static let events = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore/Events")

    private func source(_ name: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.events.appendingPathComponent(name)
        )
    }

    @Test("each gate caller states whether the window is tracked")
    func callersStateTracked() throws {
        #expect(
            try source("EventLoop+Tracking.swift")
                .occurrences(of: "tracked: false") == 1
        )
        #expect(
            try source("EventLoop+Reconcile.swift")
                .occurrences(of: "tracked: elements[pid]?[id] != nil,") == 1
        )
        #expect(
            try source("EventLoop+WindowPolicy.swift")
                .occurrences(of: "FloatDetection.judgedLayer(") == 1
        )
    }

    /// The classifier hands the panel predicate the layer it read,
    /// or no raised window — a launcher's or the level's — arms
    /// the #244 distrust.
    @Test("the untracked-focus classifier passes the layer it read")
    func classifierPassesTheLayer() throws {
        let classifier = try source("EventLoop+UntrackedFocus.swift")
        #expect(
            classifier.occurrences(
                of: "let layer = FloatDetection.windowLayer(of: id) ?? 0"
            ) == 1
        )
        let call = try #require(
            classifier.range(of: "FloatDetection.isBuiltInIgnoredPanel(")
        )
        let args = classifier[call.upperBound...].prefix(160)
        #expect(args.contains("layer: layer,"))
    }
}
