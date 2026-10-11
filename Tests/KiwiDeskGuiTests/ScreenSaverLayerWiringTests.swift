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
}
