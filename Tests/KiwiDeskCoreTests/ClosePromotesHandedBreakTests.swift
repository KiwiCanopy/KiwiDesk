import Foundation
import Testing

@testable import KiwiDeskCore

/// The gone handler's arm of #1387: a plain CLOSE makes the
/// departure fold's break hand-off permanent, so the holder heads
/// its track by right; a vanish (a Desktop departure) leaves it
/// revocable for the head's return.
@Suite("A close promotes the handed break (#1387)", .serialized)
@MainActor
struct ClosePromotesHandedBreakTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-closepromote-\(UUID().uuidString)"
                )
        )
    }

    @Test("a closed head's holder becomes a head of its own")
    func closePromotesTheHolder() throws {
        let core = makeCore()
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.setMode(space, .track)
        let head = WindowID(1)
        let holder = WindowID(2)
        // New windows land first, so the head is created last.
        for id in [holder, head] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "App")
                )
            )
        }
        core.state.workspaces.withSpace(space) { $0.trackBreaks = [head] }
        #expect(core.state.workspaces[space]?.windows == [head, holder])
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            head,
            wasMinimized: false,
            effects: &effects
        )
        #expect(core.state.workspaces[space]?.handedBreaks == [holder])
        // A window the compositor hosts nowhere: closed.
        let reason = core.handleWindowGone(
            head,
            wasMinimized: false,
            effects: effects
        )
        #expect(reason == .closed)
        #expect(core.state.workspaces[space]?.handedBreaks == [])
        #expect(core.state.workspaces[space]?.trackBreaks == [holder])
        #expect(core.state.departedSlots[head]?.handedTo == nil)
    }
}
