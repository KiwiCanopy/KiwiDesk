import Foundation
import Testing

/// #837: the install and the repair both take the one bounded
/// `register`, both record its stall, the repair is gated on the
/// back-off and ordered with the stalled add last, and a session's
/// return forgets the stall (#1285). `ObserverRegistrationBoundTests`
/// pins the pure decisions; this pins that each site reaches them.
@Suite("Observer registration wiring (#837)")
struct ObserverRegistrationSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func count(_ needle: String, in path: String) throws -> Int {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
        return source.components(separatedBy: needle).count - 1
    }

    @Test("install and repair register through the one bounded loop")
    func bothSitesTakeTheBound() throws {
        let file = "Sources/KiwiDeskCore/AX/AXApplicationObserver.swift"
        #expect(
            try count("record(register(Self.appNotifications))", in: file)
                == 1
        )
        #expect(
            try count(
                "record(\n            register(\n"
                    + "                Self.repairOrder(",
                in: file
            ) == 1
        )
        #expect(try count("stalledAt: stalledAt,", in: file) == 1)
        // The instance wrapper reaches the bounded static, on the
        // observer's own clock.
        #expect(
            try count("return Self.register(names, now: now) {", in: file)
                == 1
        )
        // The bounded loop's add and the per-window one.
        #expect(try count("AXObserverAddNotification(", in: file) == 2)
    }

    @Test("a session's return forgets every observer's stall")
    func sessionReturnForgetsTheStall() throws {
        #expect(
            try count(
                "for observer in observers.values { "
                    + "observer.forgetRepairStall() }",
                in: "Sources/KiwiDeskCore/Events/EventLoop+Heal.swift"
            ) == 1
        )
    }
}
