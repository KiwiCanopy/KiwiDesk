import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A Tile over a float rule crosses an in-place restart alone
/// (#2975): the stop's capture carries it under a pinned key, and a
/// restore takes it back only where the rule still floats the
/// window. Split from `TileOverRuleTests` for file size (§2).
@Suite("Tile over a rule across a restart (#2975)", .serialized)
@MainActor
struct TileOverRuleCarryTests {
    private let id = WindowID(1)
    private let pid: pid_t = 900_976

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-tile-over-rule-carry-\(UUID().uuidString)"
                )
        )
    }

    private func arrive(_ core: KiwiCore, _ verdict: FloatVerdict) {
        var window = ManagedWindow(
            id: id,
            pid: pid,
            appName: "App",
            title: "Doc"
        )
        window.isFloating = verdict.floats
        core.eventLoop.detectedFloating[id] = verdict
        core.handle(.windowCreated(window))
    }

    private func tiledOverRule() -> KiwiCore {
        let core = makeCore()
        arrive(core, .floats(.rule))
        #expect(core.execute("make_tiled").isSuccess)
        return core
    }

    /// The in-place stop carries the record; every other capture,
    /// and a crash with it, floats the window again.
    @Test("the in-place stop carries the Tile, a plain capture none")
    func inPlaceCarries() throws {
        let core = tiledOverRule()
        let carried = core.state.inPlaceSnapshot(
            monocleShown: [:],
            ratios: { _ in .init(entries: [:], drawn: SessionRatios()) }
        )
        let record = try #require(
            carried.windows.first { $0.windowID == id }
        )
        #expect(record.session?.tiledOverRule == true)
        #expect(
            core.state.snapshot().windows.allSatisfy {
                $0.session?.tiledOverRule == nil
            }
        )
        // Restored into a process whose scan floated it by the rule.
        let next = makeCore()
        arrive(next, .floats(.rule))
        next.restore(carried)
        #expect(next.state.windows[id]?.isFloating == false)
        #expect(next.state.tilesOverRule(id))
        // A verdict no longer the rule's takes nothing back.
        let dialog = makeCore()
        arrive(dialog, .floats(.panel))
        dialog.restore(carried)
        #expect(dialog.state.windows[id]?.isFloating == true)
        #expect(dialog.state.tiledOverRule.isEmpty)
    }

    /// The key is a stored shape: a rename strands every carried
    /// Tile across the update's in-place restart.
    @Test("the session's key is pinned")
    func keyIsPinned() throws {
        let session = StateSnapshot.WindowSession(
            sticky: .none,
            stickyReach: nil,
            tiledOverRule: true
        )
        let json = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(session)
            ) as? [String: Any]
        )
        #expect(json["tiled_over_rule"] as? Bool == true)
        let none = try #require(
            JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    StateSnapshot.WindowSession(
                        sticky: .none,
                        stickyReach: nil
                    )
                )
            ) as? [String: Any]
        )
        #expect(none["tiled_over_rule"] == nil)
    }
}
