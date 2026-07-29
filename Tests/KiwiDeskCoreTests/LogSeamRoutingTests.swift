import Foundation
import Testing

@testable import KiwiDeskCore

/// `LogSeamWiringTests` (GUI target) proves every `var onLog`
/// seam in Core is *assigned* in `KiwiCore+Bootstrap`. It cannot
/// prove the assignment *routes* — `socket.onLog = { _ in }`
/// would satisfy a source scan — so this runs one line through
/// the wiring and checks it comes out of the sink.
///
/// **What it proves, exactly.** All seven seams are *currently*
/// assigned the same forwarding closure, so probing any of them
/// probes that one body — and that premise is an assumption
/// about the tree, not something either guard enforces: an
/// eighth seam wired with its own inline body would be dead with
/// both of them green. The first and last of the group are
/// probed rather than one, so a future split that leaves the
/// group half-shared still has a foot in each half.
///
/// What it does *not* do is enumerate the seams — a hand list
/// would go stale the first time an eighth arrives, and the
/// source scan is what keeps the set honest. Closing that half
/// properly wants runtime discovery over `Mirror`, which is a
/// piece of design work rather than a longer list.
@Suite("Log-seam routing")
@MainActor
struct LogSeamRoutingTests {
    @Test("A seam's line comes out of KiwiCore.onLog")
    func seamsReachTheSink() {
        let core = makeTestCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }

        core.crash.onLog("from the crash recorder")
        core.bus.onLog("from the bus")

        #expect(
            logs == ["from the crash recorder", "from the bus"]
        )
    }
}
