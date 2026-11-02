import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A session-store heal never writes from a membership a Desktop
/// switch mixed (#2907): while a member is on a Desktop nobody
/// shows, or inside the switch's grace, the split and track heals
/// stand down; once the Space holds only shown windows, they heal
/// as they always did. Display and `min_window_size` pinned
/// (#531, #660).
@Suite("Heals stand down over a mixed membership (#2907)", .serialized)
@MainActor
struct HealStandDownTests {
    private let away = WindowID(2)

    private func makeCore(
        windows count: Int,
        mode: String
    ) -> (KiwiCore, SpaceID) {
        let directory =
            testTemporaryDirectory
            .appendingPathComponent(
                "kiwidesk-heal-stand-down-\(UUID().uuidString)"
            )
        let core = makeTestCore(configDirectory: directory)
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300))
        if mode == "track" {
            core.execute(
                "track.set_new_window",
                args: [.string("own_track")]
            )
        }
        for id in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return (core, space)
    }

    /// A corroborated 700 pt floor on `window`: two distinct asks,
    /// each refused twice (the ladder is `SizeBoundLearnerTests`).
    private func seedFloor(_ core: KiwiCore, window: WindowID) {
        for step in [CGFloat(60), CGFloat(110)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    window,
                    size: CGSize(width: 700 - step, height: 385)
                )
                core.tiler.boundLearner.observe(
                    window,
                    currentSize: CGSize(width: 700, height: 385),
                    settledRead: true
                )
            }
        }
        #expect(core.tiler.sizeBound(for: window)?.minWidth == 700)
    }

    private func ratio(_ core: KiwiCore, _ space: SpaceID) -> Double {
        core.tiler.settings.resolvedBsp(
            for: core.state.workspaces[space]!
        ).splitRatioH
    }

    /// The bsp ratio one retile leaves, with `shown` answering the
    /// shown-Desktop read and `sinceSwitch` the last switch's age.
    private func healedRatio(
        shown: @escaping (WindowID) -> Bool?,
        sinceSwitch: TimeInterval = 60
    ) -> (ratio: Double, healed: Bool) {
        let (core, space) = makeCore(windows: 2, mode: "bsp")
        seedFloor(core, window: away)
        core.windowIsOnShownDesktop = shown
        core.lastDesktopSwitch = Date(timeIntervalSinceNow: -sinceSwitch)
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.retile()
        return (
            ratio(core, space),
            log.contains { $0.contains("split ratio healed") }
        )
    }

    @Test("A member on a Desktop nobody shows stands the split heal down")
    func awayMemberStandsSplitDown() {
        guard NSScreen.main != nil else { return }
        let result = healedRatio { $0 == self.away ? false : true }
        #expect(!result.healed)
        #expect(result.ratio == 0.5)
    }

    @Test("Shown members heal, and so does a read that cannot answer")
    func shownAndUnansweredHeal() {
        guard NSScreen.main != nil else { return }
        let shown = healedRatio { _ in true }
        let unanswered = healedRatio { _ in nil }
        #expect(shown.healed && unanswered.healed)
        #expect(shown.ratio < 0.5)
        #expect(unanswered.ratio == shown.ratio)
    }

    @Test("The switch's grace stands the heal down, and only it")
    func graceStandsDown() {
        guard NSScreen.main != nil else { return }
        let inside = healedRatio(shown: { _ in true }, sinceSwitch: 0.1)
        let past = healedRatio(
            shown: { _ in true },
            sinceSwitch: EventLoop.spaceSwitchCoalesceGrace + 0.1
        )
        #expect(!inside.healed)
        #expect(inside.ratio == 0.5)
        #expect(past.healed)
    }

    /// The device ratchet (2026-11-02): mixed passes wrote the
    /// shared ratio one way, then the other. A mixed pass now
    /// leaves the pure heal exactly where it alone would land.
    @Test("A mixed pass then a pure one lands where the pure heal does")
    func mixedThenPureIsPure() {
        guard NSScreen.main != nil else { return }
        let (core, space) = makeCore(windows: 2, mode: "bsp")
        seedFloor(core, window: away)
        core.lastDesktopSwitch = .distantPast
        var mixed = true
        core.windowIsOnShownDesktop = { id in
            mixed && id == self.away ? false : true
        }
        core.retile()
        #expect(ratio(core, space) == 0.5)
        mixed = false
        core.retile()
        #expect(ratio(core, space) == healedRatio { _ in true }.ratio)
    }

    @Test("A member on a Desktop nobody shows stands the track heal down")
    func awayMemberStandsTrackDown() {
        guard NSScreen.main != nil else { return }
        func weight(away awayRead: Bool) -> Double? {
            let (core, space) = makeCore(windows: 3, mode: "track")
            core.state.workspaces.withSpace(space) {
                $0.trackWeights[WindowID(1)] = 10
            }
            core.lastDesktopSwitch = .distantPast
            core.windowIsOnShownDesktop = { id in
                awayRead && id == self.away ? false : true
            }
            core.retile()
            return core.state.workspaces[space]?
                .trackWeights[WindowID(1)]
        }
        #expect(weight(away: true) == 10)
        #expect(weight(away: false) != 10)
    }
}
