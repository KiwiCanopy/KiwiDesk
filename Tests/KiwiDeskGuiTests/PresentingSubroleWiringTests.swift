import Foundation
import Testing

/// The subrole the show verdict reads (#1788 item 5) is written
/// by the event loop alone, at wirings no behavior suite reaches:
/// `track`'s next reads are direct AX calls, and the cover
/// crossing's re-read rides a live off-main reconcile. Every
/// presenting suite builds `ManagedWindow(subrole:)` by hand, so
/// a deleted wiring leaves them green while production falls
/// back to the frame alone.
@Suite("Presenting subrole wiring (#1788)")
struct PresentingSubroleWiringTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/" + path)
        return try SourceScan.strippedSource(at: url)
    }

    private func count(_ needle: String, in source: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }

    @Test("adoption files the subrole and seeds the recheck")
    func trackFilesTheSubrole() throws {
        let body = try SourceScan.functionBody(
            of: "track",
            in: "EventLoop+Tracking.swift",
            under: "Events"
        )
        try #require(!body.isEmpty)
        #expect(body.contains("window.subrole = subrole"))
        #expect(body.contains("detectedSubroles[window.id] = subrole"))
    }

    /// Both recheck paths — the element read and the off-main
    /// reading — re-file it, beside the definition.
    @Test("both rechecks refresh the subrole")
    func rechecksRefresh() throws {
        let tracking = try source("Events/EventLoop+Tracking.swift")
        #expect(count("applySubrole(", in: tracking) == 3)
        #expect(tracking.contains("applySubrole(facts.subrole, id: id)"))
        #expect(tracking.contains("applySubrole(reading.subrole, id: id)"))
    }

    /// A move or resize retiles nothing, so the crossing is where
    /// a window that dropped its title bar as it covered is asked.
    @Test("a cover crossing re-reads the subrole")
    func crossingRereads() throws {
        let events = try source("App/KiwiCore+Events.swift")
        let crossing = try #require(
            events.range(of: "crossedScreenCover(event")
        )
        let tail = String(events[crossing.upperBound...].prefix(400))
        let call = "eventLoop.reconcileForCoverCrossing(of: id)"
        #expect(count(call, in: tail) == 2)
    }
}
