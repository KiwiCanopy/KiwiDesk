import Foundation
import Testing

/// #837: the observer keeps no registration state of its own — the
/// install and the repair file their outcome in the one
/// `ObserverRegistrationLedger`, the repair is asked in its order
/// and gated on its back-off, a session's return forgets its stall
/// (#1285), and the wrapper reaches the bounded `register`.
/// `ObserverRegistrationBoundTests` pins the ledger and the loop;
/// this pins that each observer member reaches them.
@Suite("Observer registration wiring (#837)")
struct ObserverRegistrationSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private let file = "Sources/KiwiDeskCore/AX/AXApplicationObserver.swift"

    private func count(_ needle: String, in path: String) throws -> Int {
        let source = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
        return source.components(separatedBy: needle).count - 1
    }

    @Test("each observer member reaches the ledger and the bound")
    func membersReachTheLedger() throws {
        let needles = [
            "ledger.record(register(Self.appNotifications), at: now())",
            "ledger.record(\n"
                + "            register(ledger.repairOrder("
                + "of: Self.appNotifications)),\n"
                + "            at: now()\n",
            "public var needsRegistrationRepair: Bool {\n"
                + "        ledger.needsRepair(now: now())\n    }",
            "public func forgetRepairStall() { ledger.forgetStall() }",
            // The wrapper reaches the bounded static, on the
            // observer's own clock.
            "return Self.register(names, now: now) {",
        ]
        for needle in needles {
            #expect(try count(needle, in: file) == 1, "\(needle)")
        }
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
