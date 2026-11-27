import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A cold boot runs `init.lua` before any screen is published, so a
/// split or a bar's per-screen value given by screen name or number
/// waits for the first report of a screen, in call order with the
/// held pins (#3640, beside #3631's `BootSpacePinTests`).
@Suite("Boot applies init.lua's screen splits (#3640)", .serialized)
@MainActor
struct BootDisplayAreaTests {
    private static let external = Display(
        id: DisplayID(900_641),
        name: "LG HDR 4K",
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440)
    )
    private static let builtIn = Display(
        id: DisplayID(900_640),
        name: "Built-in Retina Display",
        frame: CGRect(x: 2560, y: 0, width: 1512, height: 982)
    )
    private static let split = """
        KiwiDesk.set_display_areas(
          "Built-in Retina Display", "side_by_side", 756, 756)
        """
    private static var rightArea: String {
        "\(builtIn.fingerprint)#1"
    }

    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3640-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        return core
    }

    private func load(_ core: KiwiCore, _ lua: String) throws {
        try (lua + "\n").write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
    }

    private func areas(_ core: KiwiCore) -> Int {
        core.state.workspaces.placements(of: Self.builtIn.id).count
    }

    private func dock(_ core: KiwiCore) {
        core.handle(.displaysChanged([Self.external, Self.builtIn]))
    }

    /// Runs `body` with the external screen as main, so screen 2 is
    /// the built-in one.
    private func externalMain(_ body: () throws -> Void) rethrows {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        PositionalDisplays.mainIDOverride = { Self.external.id }
        try body()
    }

    @Test("a split by name loaded with no screen lands at the report")
    func nameSplitApplies() throws {
        let core = try makeCore()
        try load(core, Self.split)
        #expect(core.tiler.settings.displayAreas.isEmpty)
        dock(core)
        #expect(areas(core) == 2)
        #expect(core.heldScreenCalls.isEmpty)
        // The held split is Lua's: a reload that drops it undoes it.
        // The reload keeps a setting so `init.lua` still owns them.
        try load(core, #"space_bar.set_visibility("auto")"#)
        #expect(areas(core) == 1)
    }

    /// A number names a split's own key (#3647 ▸ lane 3), so it is
    /// stored at once as Screen 2's shares, read against its sizes,
    /// and nothing waits for the report.
    @Test("a split by number is stored at once, held by nothing")
    func numberSplitApplies() throws {
        try externalMain {
            let core = try makeCore()
            try load(
                core,
                #"KiwiDesk.set_display_areas(2, "side_by_side", 756, 756)"#
            )
            #expect(core.heldScreenCalls.isEmpty)
            #expect(
                core.tiler.settings.displayAreas[number: 2]?.areas
                    .map(\.w) == [500, 500]
            )
            dock(core)
            #expect(areas(core) == 2)
        }
    }

    /// A fingerprint needs the order at the report to give it a
    /// number, so it waits now too (#3647 ▸ lane 3).
    @Test("a split by fingerprint waits for the report")
    func fingerprintSplitWaits() throws {
        let core = try makeCore()
        try load(
            core,
            """
            KiwiDesk.set_display_areas(
              "\(Self.builtIn.fingerprint)", "side_by_side", 756, 756)
            """
        )
        #expect(core.tiler.settings.displayAreas.isEmpty)
        #expect(!core.heldScreenCalls.isEmpty)
        dock(core)
        #expect(areas(core) == 2)
    }

    @Test("a pin on an area of a held split lands in that area")
    func pinFollowsItsHeldSplit() throws {
        let core = try makeCore()
        let pin = """
            KiwiDesk.pin_space_to_display("Calls", "\(Self.rightArea)")
            """
        try load(core, Self.split + "\n" + pin)
        dock(core)
        #expect(core.spacePins["Calls"] == Self.rightArea)
    }

    @Test("an area named behind a held split keeps its name")
    func nameFollowsItsHeldSplit() throws {
        let core = try makeCore()
        let lua = """
            KiwiDesk.set_display_area_name("\(Self.rightArea)", "Right")
            KiwiDesk.pin_space_to_display("Calls", "Right")
            """
        try load(core, Self.split + "\n" + lua)
        dock(core)
        let split = core.tiler.settings.displayAreas
            .split(
                on: Self.builtIn.fingerprint,
                order: core.liveScreenOrder,
                floors: .unfloored
            )
        #expect(split?.areas.first { $0.id == 1 }?.name == "Right")
        #expect(core.spacePins["Calls"] == Self.rightArea)
    }

    @Test("a call outside a config load answers as it always did")
    func callOutsideALoadIsNotHeld() throws {
        let core = try makeCore()
        let reply = core.execute(
            "set_display_areas",
            args: [
                .string(Self.builtIn.name), .string("side_by_side"),
                .number(756), .number(756),
            ]
        )
        #expect(!reply.isSuccess)
        #expect(core.heldScreenCalls.isEmpty)
    }

    @Test("a bar value by name writes every area of a held split")
    func barCallFansOutOverTheSplit() throws {
        let core = try makeCore()
        let bar = """
            space_bar.set_visibility("hidden", "Built-in Retina Display")
            """
        try load(core, Self.split + "\n" + bar)
        #expect(
            core.tiler.settings.spaceBarStyle.visibilityOverride.isEmpty
        )
        dock(core)
        #expect(
            Set(core.tiler.settings.spaceBarStyle.visibilityOverride.keys)
                == [Self.builtIn.fingerprint, Self.rightArea]
        )
    }

    @Test("a bar edge by number lands on that screen at the report")
    func edgeByNumberApplies() throws {
        try externalMain {
            let core = try makeCore()
            try load(core, #"space_bar.set_edge("left", 2)"#)
            #expect(core.tiler.settings.spaceBarStyle.edgeOverride.isEmpty)
            dock(core)
            #expect(
                core.tiler.settings.spaceBarStyle.edge(
                    on: Self.builtIn.fingerprint
                ) == .left
            )
        }
    }

    @Test("a report of no screen keeps what is held")
    func emptyReportKeepsTheList() throws {
        let core = try makeCore()
        try load(core, Self.split)
        core.handle(.displaysChanged([]))
        let held = core.heldScreenCalls.filter(\.isSplit)
        #expect(!held.isEmpty)
        dock(core)
        #expect(areas(core) == 2)
    }

    @Test("a load whose settings a profile replaced holds nothing")
    func replacedLoadDropsItsHeldCalls() throws {
        let core = try makeCore()
        let profile = core.buildProfile(name: "desk", modes: nil)
        _ = try core.saveProfile(profile)
        core.apply(profile: profile, cause: .explicit)
        try load(core, Self.split)
        let held = core.heldScreenCalls.filter(\.isSettings)
        #expect(held.isEmpty)
        dock(core)
        #expect(areas(core) == 1)
    }

    /// A load that holds a split settles once that split is stored:
    /// settled first, the screen Lua split before would go whole,
    /// and its merge would move the right area's value to the left.
    @Test("a held split defers the load's settle")
    func heldSplitDefersTheSettle() throws {
        let core = try makeCore()
        dock(core)
        let byPrint = """
            KiwiDesk.set_display_areas(
              "\(Self.builtIn.fingerprint)", "side_by_side", 756, 756)
            """
        try load(core, byPrint)
        try #require(areas(core) == 2)
        core.handle(.displaysChanged([]))
        let bar = """
            space_bar.set_visibility("hidden", "\(Self.rightArea)")
            """
        try load(core, Self.split + "\n" + bar)
        dock(core)
        #expect(areas(core) == 2)
        #expect(
            core.tiler.settings.spaceBarStyle.visibilityOverride
                == [Self.rightArea: .hidden]
        )
    }
}
