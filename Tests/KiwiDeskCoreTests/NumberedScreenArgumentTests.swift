import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A screen number in Lua or the CLI is Screen N (#3647 ▸ a Lua or
/// CLI screen number is Screen N): the live profile's numbering for
/// the connected screens, else left to right. `list_monitors` lists
/// in that order, `N#id` names Screen N's area, and a setup the
/// profile does not hold takes its numbers left to right.
@Suite("Screen numbers in Lua and the CLI (#3647)", .serialized)
@MainActor
struct NumberedScreenArgumentTests {
    private let screenA = Display(
        id: DisplayID(1),
        name: "A",
        frame: CGRect(x: 0, y: 0, width: 100, height: 100)
    )
    private let screenB = Display(
        id: DisplayID(2),
        name: "B",
        frame: CGRect(x: 100, y: 0, width: 100, height: 100)
    )

    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-3647n-\(UUID().uuidString)")
        )
    }

    private func connect(_ core: KiwiCore, _ displays: [Display]) {
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        for display in displays {
            core.state.workspaces.upsertDisplay(display)
        }
    }

    /// A profile whose stored order runs right to left.
    private func loadRightToLeft(_ core: KiwiCore) throws {
        try core.profiles.write(
            Profile(
                name: "Desk",
                monitorSets: [
                    MonitorSet(monitors: ["B:100x100", "A:100x100"])
                ],
                spaces: ["1"],
                spaceModes: ["1": .bsp],
                settings: TilingSettings()
            )
        )
        try core.loadProfile(named: "Desk")
    }

    @Test("a number names the screen the profile numbers so")
    func numberFollowsTheOrder() throws {
        let core = makeCore()
        connect(core, [screenA, screenB])
        #expect(core.resolveDisplayArg(.number(1)) == screenA.id)
        try loadRightToLeft(core)
        #expect(core.resolveDisplayArg(.number(1)) == screenB.id)
        #expect(core.resolveDisplayArg(.number(2)) == screenA.id)
        #expect(core.resolveDisplayArg(.number(3)) == nil)
    }

    @Test("list_monitors lists Screen 1 onwards with its number")
    func listInScreenOrder() throws {
        let saved = PositionalDisplays.mainIDOverride
        defer { PositionalDisplays.mainIDOverride = saved }
        let core = makeCore()
        PositionalDisplays.mainIDOverride = { DisplayID(1) }
        connect(core, [screenA, screenB])
        try loadRightToLeft(core)
        guard case .array(let monitors)? = core.listMonitors().data else {
            Issue.record("no monitor list")
            return
        }
        let rows = monitors.compactMap { entry -> [String: JSONValue]? in
            if case .object(let row) = entry { return row }
            return nil
        }
        #expect(
            rows.map { $0["fingerprint"] } == [
                .string("B:100x100"), .string("A:100x100"),
            ]
        )
        #expect(rows.map { $0["screen"] } == [.number(1), .number(2)])
        #expect(rows.map { $0["main"] } == [.bool(false), .bool(true)])
    }

    @Test("N#id names Screen N's area")
    func numberedAreaKey() throws {
        let core = makeCore()
        connect(core, [screenA, screenB])
        try loadRightToLeft(core)
        let named = try #require(core.numberedArea("1#2"))
        #expect(named.0.id == screenB.id)
        #expect(named.1 == ScreenAreaKey(fingerprint: "B:100x100", areaID: 2))
        #expect(core.numberedArea("3#1") == nil)
        #expect(core.numberedArea("1") == nil)
    }

    /// Two screens wide enough to split, numbered right to left,
    /// with Screen 1 (the right one, "R") split in two.
    private func splitScreenOne(_ core: KiwiCore) throws -> Display {
        let left = Display(
            id: DisplayID(7),
            name: "L",
            frame: CGRect(x: 0, y: 0, width: 400, height: 200)
        )
        let right = Display(
            id: DisplayID(8),
            name: "R",
            frame: CGRect(x: 400, y: 0, width: 400, height: 200)
        )
        connect(core, [left, right])
        try core.profiles.write(
            Profile(
                name: "Wide",
                monitorSets: [
                    MonitorSet(monitors: [right.fingerprint, left.fingerprint])
                ],
                spaces: ["1"],
                spaceModes: ["1": .bsp],
                settings: TilingSettings()
            )
        )
        try core.loadProfile(named: "Wide")
        let reply = core.execute(
            "set_display_areas",
            args: [
                .number(1), .string("side_by_side"),
                .number(200), .number(200),
            ]
        )
        #expect(reply.isSuccess)
        return right
    }

    @Test("a verb takes N#id, and list_monitors prints it")
    func numberedAreaThroughTheVerbs() throws {
        let core = makeCore()
        let right = try splitScreenOne(core)
        let stored = core.tiler.settings.displayAreas
        // Stored as Screen 1's shares, never by fingerprint.
        #expect(stored.keys.sorted() == ["1"])
        let named = core.execute(
            "set_display_area_name",
            args: [.string("1#1"), .string("Code")]
        )
        #expect(named.isSuccess)
        let areas = core.tiler.settings.displayAreas
            .split(on: right.fingerprint, order: core.liveScreenOrder)?
            .areas
        #expect(areas?.first { $0.id == 1 }?.name == "Code")
        let placed = core.resolveAreaArg(.string("1#1"))
        #expect(placed?.display == right.id)
        #expect(placed?.area == 1)
        guard case .array(let monitors)? = core.listMonitors().data,
            case .object(let first)? = monitors.first,
            case .array(let split)? = first["areas"]
        else {
            Issue.record("no areas on Screen 1")
            return
        }
        let keys = split.compactMap { entry -> JSONValue? in
            if case .object(let area) = entry { return area["numbered_key"] }
            return nil
        }
        #expect(keys == [.string("1"), .string("1#1")])
    }

    @Test("an area may not be named like a numbered key")
    func numberedNameRefused() {
        let problem = ScreenArea.nameProblem(
            "2#1",
            for: ScreenAreaKey(fingerprint: "A:100x100", areaID: 1),
            splits: [:],
            screenNames: []
        )
        #expect(problem == .number)
    }

    /// The count's default loads on a same-count setup it does not
    /// hold, and its numbers land left to right (#3647 ▸ lane 2).
    @Test("an unheld setup takes the profile's pins left to right")
    func unheldSetupTakesPins() throws {
        let core = makeCore()
        try core.profiles.write(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["X:100x100", "Y:100x100"])
                ],
                spaceMonitorMap: ["2": ScreenSlotKey(number: 2)!],
                isDefault: true,
                spaces: ["1", "2"],
                spaceModes: ["1": .bsp, "2": .bsp],
                settings: TilingSettings()
            )
        )
        core.handle(.displaysChanged([screenA, screenB]))
        #expect(core.profiles.currentName == "Work")
        #expect(core.spacePins["2"] == "B:100x100")
    }
}
