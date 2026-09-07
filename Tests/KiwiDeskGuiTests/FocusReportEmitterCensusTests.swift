import Foundation
import Testing

/// **Every `.windowFocused` emitter in `Events/` is censused, and
/// the AX one is gated** (#1322).
///
/// Two emitters exist: the AX focused-window branch, which asks
/// `reportsFromActiveApp`, and the activation channel, which is
/// the gate's fallback and needs none. A third — a main-window
/// change, a settle re-report — would be ungated silently, so
/// the sites are pinned by count and the gated one by name.
@Suite("Focus report emitter census (#1322)")
struct FocusReportEmitterCensusTests {
    private static let emitter = "onEvent(.windowFocused("
    /// The CALL shape, so the gate's own declaration in the same
    /// file cannot satisfy it (guard-prover); a non-`guard` call
    /// shape would have to re-spell this needle, stated.
    private static let gate = "guard reportsFromActiveApp("

    /// The census: file → whether it asks the gate.
    private static let emitters: [String: Bool] = [
        "EventLoop+FocusReport.swift": true,
        "EventLoop+Apps.swift": false,
    ]

    private static var eventsRoot: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Events")
    }

    @Test("The emitters are exactly the censused ones")
    func emittersAreCensused() throws {
        var found: [String: Bool] = [:]
        var scanned = 0
        for file in try SourceScan.swiftSources(under: Self.eventsRoot) {
            scanned += 1
            let source = try SourceScan.strippedSource(at: file)
            guard source.contains(Self.emitter) else { continue }
            found[file.lastPathComponent] = source.contains(Self.gate)
        }
        #expect(scanned >= 10, "scanned \(scanned) files")
        #expect(
            found == Self.emitters,
            "emitters and the census disagree: \(found)"
        )
    }

    /// The needles, proved against literal sites so a renamed
    /// spelling cannot leave the clause green on nothing.
    @Test("Every needle matches the spelling it names")
    func needlesMatchTheirSubject() {
        #expect("onEvent(.windowFocused(id))".contains(Self.emitter))
        #expect(
            "guard reportsFromActiveApp(pid) else {".contains(Self.gate)
        )
        #expect(
            !"func reportsFromActiveApp(_ pid: pid_t) -> Bool {"
                .contains(Self.gate),
            "the declaration satisfies the gate needle"
        )
        #expect(!"onEvent(.windowHidden(id))".contains(Self.emitter))
    }
}
