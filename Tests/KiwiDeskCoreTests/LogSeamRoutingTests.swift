import Foundation
import Testing

@testable import KiwiDeskCore

/// `LogSeamWiringTests` (GUI target) proves every `var onLog`
/// seam in Core is *assigned* in `KiwiCore+Bootstrap`. It cannot
/// prove the assignment *routes* — `socket.onLog = { _ in }`
/// would satisfy a source scan — so this runs one line through
/// the wiring and checks it comes out of the sink.
///
/// **What it proves, exactly.** All seven seams are assigned the
/// same forwarding closure, so probing any of them probes that
/// one body: two are picked from opposite ends of the group
/// rather than one, so a future split that leaves the group
/// half-shared still has a foot in each half. What it does *not*
/// do is enumerate the seams — a hand list would go stale the
/// first time an eighth arrives, and the source scan is what
/// keeps the set honest. Closing that gap properly wants runtime
/// discovery over `Mirror`, which is a piece of design work, not
/// a longer list.
@Suite("Log-seam routing")
@MainActor
struct LogSeamRoutingTests {
    @Test("A seam's line comes out of KiwiCore.onLog")
    func seamsReachTheSink() {
        let core = makeTestCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }

        core.socket.onLog("from the socket")
        core.bus.onLog("from the bus")

        #expect(logs == ["from the socket", "from the bus"])
    }
}
