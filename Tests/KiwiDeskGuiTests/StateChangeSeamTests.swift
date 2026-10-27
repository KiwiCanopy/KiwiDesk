import Foundation
import Testing

/// #2676: the state change's ring hold has one door, and its spring
/// end reaches the hold through one chained callback. Source scans,
/// off the main actor; the behaviour is `StateChangeRingTests`'.
@Suite("State change seams (#2676)")
struct StateChangeSeamTests {
    private var core: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
    }

    /// Files under `Sources/KiwiDeskCore` whose comment-stripped
    /// source contains `needle`, with how often.
    private func sites(of needle: String) throws -> [String: Int] {
        var found: [String: Int] = [:]
        let scanned = try SourceScan.swiftSources(under: core)
        #expect(!scanned.isEmpty)
        for file in scanned {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count = source.components(separatedBy: needle).count - 1
            if count > 0 { found[file.lastPathComponent] = count }
        }
        return found
    }

    @Test("the ring hold is armed from the one door")
    func oneDoor() throws {
        #expect(
            try sites(of: "borders.holdStateChange(")
                == ["KiwiCore+StateChange.swift": 1]
        )
    }

    /// The hold lets go when the spring ends: Bootstrap wraps the
    /// engine's end callback, so a third assignment would sever it.
    @Test("the animation end reaches the hold")
    func endChainIsWired() throws {
        #expect(
            try sites(of: "animation.onAnimationEnd =")
                == [
                    "TilingEngine.swift": 1,
                    "KiwiCore+Bootstrap.swift": 1,
                ]
        )
        #expect(
            try sites(of: "borders.stateChangeSettled(")
                == ["KiwiCore+Bootstrap.swift": 1]
        )
    }

    /// Every state change arms the hold: the retile for its pass's
    /// named window, the float verb for its own write.
    @Test("the hold is armed where a state change runs")
    func doorIsCalled() throws {
        #expect(
            try sites(of: "holdRingForStateChange(")
                == [
                    "KiwiCore+StateChange.swift": 1,
                    "KiwiCore+Retile.swift": 1,
                    "KiwiCore+FloatPlacement.swift": 1,
                ]
        )
    }
}
