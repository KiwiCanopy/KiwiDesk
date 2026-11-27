import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The fit rule on a running core (#3647 ▸ no-fit ruling): an apply
/// numbers a setup in the first order that fits, a Save stores the
/// base order, a floor raised later draws a split whole without
/// moving a number, and a live write under the floor is refused.
@Suite("Screen fit on apply (#3647)", .serialized)
@MainActor
struct ScreenFitApplyTests {
    private let laptop = Display(
        id: DisplayID(900_811),
        name: "Laptop",
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982)
    )
    private let wide = Display(
        id: DisplayID(900_812),
        name: "Wide",
        frame: CGRect(x: 1512, y: 0, width: 3440, height: 1440)
    )

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647f-\(UUID().uuidString)")
        )
    }

    /// "Desk" numbers the laptop 1 and splits Screen 1 in halves, at
    /// a minimum window size the laptop's halves fall under.
    private func loadDesk(_ core: KiwiCore, floor: Double = 800) throws {
        core.handle(.displaysChanged([laptop, wide]))
        var settings = TilingSettings()
        settings.minWindowSizes = MinWindowSizes(all: .square(floor))
        settings.displayAreas[number: 1] = ScreenShares(
            areas: [
                ScreenArea(id: 0, x: 0, y: 0, w: 500, h: 1000),
                ScreenArea(id: 1, x: 500, y: 0, w: 500, h: 1000),
            ]
        )
        try core.profiles.write(
            Profile(
                name: "Desk",
                monitorSets: [
                    MonitorSet(monitors: [
                        laptop.fingerprint, wide.fingerprint,
                    ])
                ],
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                settings: settings
            )
        )
        try core.loadProfile(named: "Desk")
    }

    @Test("an apply numbers the setup in the order that fits")
    func applyTakesTheFit() throws {
        let core = makeCore()
        try loadDesk(core)
        #expect(core.liveScreenOrder.fingerprints.first == wide.fingerprint)
        let splits = core.state.workspaces.areaSplits
        #expect(splits[wide.fingerprint]?.areas.count == 2)
        #expect(splits[laptop.fingerprint] == nil)
        // A Save stores the base order, never the fit.
        #expect(
            core.liveMonitorSet.monitors
                == [laptop.fingerprint, wide.fingerprint]
        )
    }

    @Test("a floor raised later draws the split whole, numbers kept")
    func floorRaiseDrawsWhole() throws {
        let core = makeCore()
        try loadDesk(core, floor: 300)
        #expect(core.liveScreenOrder.fingerprints.first == laptop.fingerprint)
        #expect(core.state.workspaces.areaSplits[laptop.fingerprint] != nil)
        core.tiler.settings.minWindowSizes = MinWindowSizes(all: .square(800))
        #expect(core.state.workspaces.areaSplits[laptop.fingerprint] == nil)
        // The number stays where the apply put it.
        #expect(core.liveScreenOrder.fingerprints.first == laptop.fingerprint)
    }

    @Test("a live split under the floor is refused")
    func liveWriteUnderTheFloorRefuses() throws {
        let core = makeCore()
        try loadDesk(core)
        let reply = core.execute(
            "set_display_areas",
            args: [
                .string(laptop.fingerprint), .string("side_by_side"),
                .number(756), .number(756),
            ]
        )
        #expect(!reply.isSuccess)
        #expect(reply.error?.contains("narrower") == true)
    }

    /// A Settings Save re-applies the live profile; raising the
    /// floor there keeps the numbers the apply chose.
    @Test("a re-apply keeps the fit; an explicit load refits")
    func reapplyKeepsTheFit() throws {
        let core = makeCore()
        try loadDesk(core, floor: 300)
        #expect(core.liveScreenOrder.fingerprints.first == laptop.fingerprint)
        var raised = try core.profiles.read(name: "Desk")
        raised.settings.minWindowSizes = MinWindowSizes(all: .square(800))
        try core.profiles.write(raised)
        core.apply(profile: raised, cause: .reapply)
        #expect(core.liveScreenOrder.fingerprints.first == laptop.fingerprint)
        #expect(core.state.workspaces.areaSplits[laptop.fingerprint] == nil)
        try core.loadProfile(named: "Desk")
        #expect(core.liveScreenOrder.fingerprints.first == wide.fingerprint)
    }

    /// A Space pinned to the wide screen while it holds the fitted
    /// Screen 1 is stored under 1, so a load of the copy puts it back.
    @Test("a new profile numbers its pins in the fitted order")
    func newProfileStoresFittedNumbers() throws {
        let core = makeCore()
        try loadDesk(core)
        core.spacePins["2"] = wide.fingerprint
        let built = core.buildProfile(name: "Copy", modes: nil)
        #expect(built.spaceMonitorMap["2"] == ScreenSlotKey(number: 1))
    }

    @Test("a split by number under the floor is refused")
    func numberedWriteUnderTheFloorRefuses() throws {
        let core = makeCore()
        try loadDesk(core)
        // Screen 1 is the wide screen in the fitted order; Screen 2,
        // the laptop, cannot hold halves at this floor.
        let reply = core.execute(
            "set_display_areas",
            args: [
                .number(2), .string("side_by_side"),
                .number(756), .number(756),
            ]
        )
        #expect(!reply.isSuccess)
        #expect(reply.error?.contains("narrower") == true)
    }
}
