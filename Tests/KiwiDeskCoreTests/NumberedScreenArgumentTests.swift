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
