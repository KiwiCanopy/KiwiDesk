import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// When the fit is chosen and whose it is (#3647 ▸ lane 3b): a fit
/// numbers the apply's pins, belongs to one profile, holds through
/// a screen change on the same screens, is chosen afresh for new
/// screens, and ends at a composed apply.
@Suite("Screen fit: when it is chosen (#3647)", .serialized)
@MainActor
struct ScreenFitRefitTests {
    private let laptop = Display(
        id: DisplayID(900_831),
        name: "Laptop",
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982)
    )
    private let wide = Display(
        id: DisplayID(900_832),
        name: "Wide",
        frame: CGRect(x: 1512, y: 0, width: 3440, height: 1440)
    )
    private let other = Display(
        id: DisplayID(900_833),
        name: "Other",
        frame: CGRect(x: 1512, y: 0, width: 3440, height: 1440)
    )

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647r-\(UUID().uuidString)")
        )
    }

    /// "Desk" numbers the laptop 1 on both its setups, splits Screen
    /// 1 in halves and pins Space 2 to Screen 1.
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
                    ]),
                    MonitorSet(monitors: [
                        laptop.fingerprint, other.fingerprint,
                    ]),
                ],
                spaceMonitorMap: ["2": ScreenSlotKey(number: 1)!],
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                settings: settings
            )
        )
        try core.loadProfile(named: "Desk")
    }

    @Test("an apply's pins land in the fitted numbering")
    func pinsFollowTheFit() throws {
        let core = makeCore()
        try loadDesk(core)
        #expect(core.spacePins["2"] == wide.fingerprint)
    }

    @Test("a number no screen holds takes a split under the floor")
    func unheldNumberIsNotJudged() throws {
        let core = makeCore()
        try loadDesk(core)
        let reply = core.execute(
            "set_display_areas",
            args: [
                .number(3), .string("side_by_side"),
                .number(500), .number(500),
            ]
        )
        #expect(reply.isSuccess)
    }

    @Test("another profile on the same screens never reads the fit")
    func fitIsTheProfiles() throws {
        let core = makeCore()
        try loadDesk(core)
        #expect(core.liveScreenOrder.fingerprints.first == wide.fingerprint)
        let plain = Profile(
            name: "Plain",
            monitorSets: [
                MonitorSet(monitors: [laptop.fingerprint, wide.fingerprint])
            ],
            spaces: ["1"],
            spaceModes: ["1": .bsp],
            settings: TilingSettings()
        )
        try core.profiles.write(plain)
        core.apply(profile: plain, cause: .event)
        #expect(core.liveScreenOrder.fingerprints.first == laptop.fingerprint)
    }

    @Test("a screen change on the same screens keeps the fit")
    func sameScreensKeepTheFit() throws {
        let core = makeCore()
        try loadDesk(core, floor: 300)
        core.tiler.settings.minWindowSizes = MinWindowSizes(all: .square(800))
        core.handle(.displaysChanged([laptop, wide]))
        #expect(core.liveScreenOrder.fingerprints.first == laptop.fingerprint)
    }

    @Test("new screens are fitted afresh")
    func newScreensRefit() throws {
        let core = makeCore()
        try loadDesk(core)
        core.handle(.displaysChanged([laptop, other]))
        #expect(core.liveScreenOrder.fingerprints.first == other.fingerprint)
    }

    @Test("a composed apply ends the fit")
    func composedApplyEndsIt() throws {
        LocalizationManager.shared.select("en")
        let core = makeCore()
        core.handle(.displaysChanged([laptop, wide]))
        let base = core.screenOrder(holding: [])
        core.profiles.screenOrders.fitted = .init(
            profile: nil,
            base: base,
            order: ScreenOrder(base.fingerprints.reversed())
        )
        #expect(core.liveScreenOrder != base)
        let composed = try #require(
            ProfileComposition.compose(
                displays: core.state.workspaces.allDisplays,
                mainID: nil
            )
        )
        core.apply(composed: composed, forceRetile: true)
        #expect(core.profiles.screenOrders.fitted == nil)
    }
}
