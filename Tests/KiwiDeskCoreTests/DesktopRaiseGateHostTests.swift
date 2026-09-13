import Foundation
import Testing

@testable import KiwiDeskCore

/// The Desktop raise gate's second read (#1410): during a
/// three-finger gesture the compositor's on-screen flag reads
/// true for every window of the neighbouring Desktops for about
/// a second, so a raise gated on the flag alone switches the
/// user to a Desktop nobody shows. The gate now asks two reads
/// and refuses when EITHER says unshown — the flag, and whether
/// the window's hosted Space is one some display currently shows,
/// which lags the draw list the other way (#1023) — while a read
/// that cannot answer abstains. Fixture ids are pinned closures;
/// the two-display topology is the one measured on 2026-09-13.
@Suite("Desktop raise gate: the shown-Desktop read (#1410)")
@MainActor
struct DesktopRaiseGateHostTests {
    private static let gestureNeedle = "#1410"
    private static let refusalNeedle = "refused"

    /// Two windows, 2 focused; 1 is the raise target.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-raise-gate-host-\(UUID().uuidString)"
                )
        )
        for raw: UInt32 in [1, 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: pid_t(raw),
                        appName: "App\(raw)"
                    )
                )
            )
        }
        core.state.workspaces.focus(WindowID(2), in: SpaceID(1))
        return core
    }

    private func pin(
        _ core: KiwiCore,
        drawn: Bool?,
        shown: Bool?
    ) {
        core.windowIsOnScreen = { _ in drawn }
        core.windowIsOnShownDesktop = { _ in shown }
    }

    /// The gesture's composite: drawn, on a Desktop no display
    /// shows. Refused, and the log names the read that refused.
    @Test("Drawn but hosted on an unshown Desktop crosses, and says so")
    func drawnOnUnshownDesktopCrosses() {
        let core = makeCore()
        pin(core, drawn: true, shown: false)
        var log: [String] = []
        core.onLog = { log.append($0) }
        #expect(core.raiseCrossesDesktops(WindowID(1)))
        #expect(log.contains { $0.contains(Self.gestureNeedle) })
    }

    /// The switch's other lag (#1023): the pointer already names
    /// the new Desktop while the draw list still composites the
    /// old one. The flag refuses first; the second read is not
    /// asked, so nothing names it.
    @Test("Not drawn but hosted on a shown Desktop crosses on the flag")
    func notDrawnOnShownDesktopCrosses() {
        let core = makeCore()
        pin(core, drawn: false, shown: true)
        var log: [String] = []
        core.onLog = { log.append($0) }
        #expect(core.raiseCrossesDesktops(WindowID(1)))
        #expect(!log.contains { $0.contains(Self.gestureNeedle) })
    }

    @Test("Both shown never crosses; a read that cannot answer abstains")
    func bothShownOrAbstainingNeverCrosses() {
        let core = makeCore()
        for (drawn, shown) in [
            (true, true), (true, nil), (nil, true), (nil, nil),
        ] as [(Bool?, Bool?)] {
            pin(core, drawn: drawn, shown: shown)
            #expect(
                !core.raiseCrossesDesktops(WindowID(1)),
                .init(
                    rawValue: "drawn \(String(describing: drawn)) "
                        + "shown \(String(describing: shown))"
                )
            )
        }
    }

    /// The host read is positive evidence of a Desktop nobody
    /// shows; an unanswered flag does not outrank it.
    @Test("An unanswered flag with an unshown host crosses")
    func unansweredFlagWithUnshownHostCrosses() {
        let core = makeCore()
        pin(core, drawn: nil, shown: false)
        #expect(core.raiseCrossesDesktops(WindowID(1)))
    }

    /// The consumer: the verb is refused WHOLE on the second read
    /// alone — state focus stays, and the log carries both lines.
    @Test("focusWindow refuses the verb on the shown-Desktop read alone")
    func focusWindowRefusesOnHostRead() {
        let core = makeCore()
        core.windowIsOnScreen = { _ in true }
        core.windowIsOnShownDesktop = { $0 != WindowID(1) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.focusWindow(WindowID(1), warp: false)
        #expect(core.activeSpace?.focused == WindowID(2))
        #expect(log.contains { $0.contains(Self.refusalNeedle) })
        #expect(log.contains { $0.contains(Self.gestureNeedle) })
    }

    @Test("A distrust re-assert stands down on the shown-Desktop read alone")
    func reassertStandsDownOnHostRead() {
        let core = makeCore()
        core.windowIsOnScreen = { _ in true }
        core.windowIsOnShownDesktop = { $0 != WindowID(1) }
        var log: [String] = []
        core.onLog = { log.append($0) }
        #expect(
            core.reassertCrossesDesktops(WindowID(1), against: WindowID(2))
        )
        #expect(log.contains { $0.contains("#1345") })
        #expect(
            !core.reassertCrossesDesktops(WindowID(2), against: WindowID(1))
        )
    }

    // MARK: - The pure verdict over the measured topology

    /// 2026-09-13: the built-in display on Desktop 3 of [1, 4, 3,
    /// 225], the DELL on 210 of [210, 5].
    private static let topology: [NativeSpace] = [
        NativeSpace(id: 1, displayUUID: "37D8", isCurrent: false),
        NativeSpace(id: 4, displayUUID: "37D8", isCurrent: false),
        NativeSpace(id: 3, displayUUID: "37D8", isCurrent: true),
        NativeSpace(id: 225, displayUUID: "37D8", isCurrent: false),
        NativeSpace(id: 210, displayUUID: "4B8F", isCurrent: true),
        NativeSpace(id: 5, displayUUID: "4B8F", isCurrent: false),
    ]

    @Test("A host on either display's current Space is shown")
    func hostOnAnyCurrentSpaceIsShown() {
        #expect(
            NativeSpaces.hostsShownSpace([3], in: Self.topology) == true
        )
        #expect(
            NativeSpaces.hostsShownSpace([210], in: Self.topology) == true
        )
    }

    /// Desktop 4 — the neighbour the gesture composites — and the
    /// DELL's hidden Desktop 5 are unshown whatever the flag says.
    @Test("A host on a Desktop no display shows is unshown")
    func hostOnUnshownDesktopIsUnshown() {
        #expect(
            NativeSpaces.hostsShownSpace([4], in: Self.topology) == false
        )
        #expect(
            NativeSpaces.hostsShownSpace([5], in: Self.topology) == false
        )
    }

    /// An all-Desktops window is hosted everywhere; one shown host
    /// is enough, whatever the list's order.
    @Test("An all-Desktops window is shown wherever the user is")
    func allDesktopsWindowIsShown() {
        #expect(
            NativeSpaces.hostsShownSpace(
                [1, 4, 5, 225, 3],
                in: Self.topology
            ) == true
        )
    }

    @Test("Hosted nowhere, or no current Space to compare, abstains")
    func nothingToCompareAbstains() {
        #expect(NativeSpaces.hostsShownSpace([], in: Self.topology) == nil)
        let noCurrent = Self.topology.map {
            NativeSpace(
                id: $0.id,
                displayUUID: $0.displayUUID,
                isCurrent: false
            )
        }
        #expect(NativeSpaces.hostsShownSpace([3], in: noCurrent) == nil)
    }
}
