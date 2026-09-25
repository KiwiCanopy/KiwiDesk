import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The #1386 re-measure after an auto-hide pref flip: two passes,
/// the second catching a bar the WindowServer draws late, and
/// none once the loop has stopped. Counted through the read seam;
/// the reads return nothing, so no shared cache is written.
@Suite("Menu-bar re-measure passes (#1386)", .serialized)
@MainActor
struct MenuBarRemeasureTests {
    private func makeCore(reads: ReadCount) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-1386-\(UUID().uuidString)"
                )
        )
        core.eventLoop.displayWatch.readDrawnMenuBars = {
            reads.count += 1
            return []
        }
        return core
    }

    private func drain(_ core: KiwiCore) async {
        // Each pass re-arms the slot from its own body, so await
        // until the slot's task is one already finished.
        for _ in 0..<4 {
            await core.deferred.task(for: .menuBarRemeasure)?.value
        }
    }

    @Test("a pref flip re-reads the bars twice")
    func twoPasses() async {
        let reads = ReadCount()
        let core = makeCore(reads: reads)
        core.eventLoop.isRunning = true
        defer { core.eventLoop.isRunning = false }
        core.scheduleMenuBarRemeasure()
        await drain(core)
        #expect(reads.count == 2)
    }

    @Test("a stopped loop re-reads nothing")
    func stoppedLoopStandsDown() async {
        let reads = ReadCount()
        let core = makeCore(reads: reads)
        core.scheduleMenuBarRemeasure()
        await drain(core)
        #expect(reads.count == 0)
    }
}

@MainActor
private final class ReadCount {
    var count = 0
}
