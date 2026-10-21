import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space's own minimum window size (#2422): it outranks the
/// layout's value at the one resolver, a float's included, and
/// Monocle still applies none.
@MainActor
@Suite("Per-Space minimum window size")
struct MinWindowSizeOverrideTests {
    private let mine = SpaceID("monitoring")
    private let other = SpaceID("work")

    private func settings() -> TilingSettings {
        var settings = TilingSettings()
        settings.minWindowSizes.grid = MinSize(width: 300, height: 240)
        settings.minWindowSizeOverride[mine] = MinSize(
            width: 220,
            height: 160
        )
        return settings
    }

    @Test("the Space's value outranks every layout's, Monocle's none")
    func spaceOutranksLayout() {
        let s = settings()
        let own = MinSize(width: 220, height: 160)
        for mode in [LayoutMode.grid, .bsp, .floating] {
            #expect(s.minWindowSize(for: mode, in: mine) == own)
        }
        #expect(s.minWindowSize(for: .monocle, in: mine) == .square(0))
    }

    @Test("another Space and no Space take the layout's value")
    func othersTakeTheLayout() {
        let s = settings()
        let grid = MinSize(width: 300, height: 240)
        #expect(s.minWindowSize(for: .grid, in: other) == grid)
        #expect(s.minWindowSize(for: .grid, in: nil) == grid)
    }

    @Test("a float in the Space takes the Space's value")
    func floatTakesTheSpace() {
        let core = makeTestCore()
        let window = WindowID(900_101)
        var managed = ManagedWindow(id: window, pid: 900_001, appName: "A")
        managed.isFloating = true
        core.state.windows.upsert(managed)
        core.state.workspaces.ensureSpace(mine, mode: .grid)
        core.state.workspaces.add(window, to: mine)
        core.tiler.settings.minWindowSizeOverride[mine] = 180
        #expect(core.minWindowSize(of: window) == 180)
        core.tiler.settings.minWindowSizeOverride[mine] = nil
        #expect(
            core.minWindowSize(of: window)
                == core.tiler.settings.minWindowSizes.floating
        )
    }

    @Test("the verb sets one Space, its height optional")
    func verbSetsOneSpace() {
        let core = makeTestCore()
        #expect(
            core.execute(
                "set_min_window_size_override",
                args: [.string("monitoring"), .number(220), .number(160)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "set_min_window_size_override",
                args: [.number(3), .number(250)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.minWindowSizeOverride == [
                mine: MinSize(width: 220, height: 160),
                SpaceID(3): 250,
            ]
        )
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes())
    }

    @Test("an argument it cannot read is refused and writes nothing")
    func verbRefuses() {
        let core = makeTestCore()
        for args: [JSONValue] in [
            [.string("monitoring")],
            [.string("monitoring"), .string("wide")],
            [.string("monitoring"), .number(220), .string("grid")],
            [.string("monitoring"), .number(2), .number(2), .number(2)],
        ] {
            #expect(
                !core.execute("set_min_window_size_override", args: args)
                    .isSuccess
            )
        }
        #expect(core.tiler.settings.minWindowSizeOverride.isEmpty)
    }

    @Test("it encodes beside min_window_size and round-trips")
    func roundTrips() throws {
        let data = try JSONEncoder().encode(settings())
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let map = try #require(
            root["min_window_size_override"] as? [String: Any]
        )
        let entry = try #require(map["monitoring"] as? [String: Any])
        #expect(entry["width"] as? Double == 220)
        #expect(entry["height"] as? Double == 160)
        let back = try JSONDecoder().decode(TilingSettings.self, from: data)
        #expect(back.minWindowSizeOverride == settings().minWindowSizeOverride)
        let bare = try JSONDecoder().decode(
            TilingSettings.self,
            from: Data("{}".utf8)
        )
        #expect(bare.minWindowSizeOverride.isEmpty)
    }

    /// An init.lua-only reload: no gui.json replaces the settings
    /// and the Space stays declared, so only the sparse reset in
    /// `resetDeclarativeState` drops a value the script stopped
    /// setting.
    @Test("a reload drops a value init.lua no longer sets")
    func reloadDropsIt() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-2422-\(UUID().uuidString)")
        )
        let declare = "KiwiDesk.set_mode(\"monitoring\", \"grid\")\n"
        try FileManager.default.createDirectory(
            at: core.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try
            (declare
            + "KiwiDesk.set_min_window_size_override(\"monitoring\", 220)\n")
            .write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        #expect(core.tiler.settings.minWindowSizeOverride[mine] == 220)
        try declare.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        #expect(core.state.workspaces[mine] != nil)
        #expect(core.tiler.settings.minWindowSizeOverride[mine] == nil)
    }

    @Test("it counts as one of the Space's overrides")
    func countsAsOne() {
        var s = TilingSettings()
        #expect(s.spaceOverrideCount(for: mine) == 0)
        s.minWindowSizeOverride[mine] = 200
        #expect(s.spaceOverrideCount(for: mine) == 1)
    }
}
