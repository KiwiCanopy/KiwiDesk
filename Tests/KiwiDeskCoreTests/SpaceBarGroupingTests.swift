import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.group_adjacent_windows` (#1725): off — the default —
/// every window draws its own glyph, so one click reaches it; on,
/// adjacent same-app runs share one glyph and a count badge
/// (`SpaceBarDriverTests` holds the grouped shape).
@Suite("Space Bar grouping toggle (#1725)")
@MainActor
struct SpaceBarGroupingTests {
    private let display = DisplayID(1)

    private func core(apps: [String]) -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwidesk-tests-\(UUID().uuidString)"
                )
        )
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        for (index, app) in apps.enumerated() {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index + 1)),
                        pid: 100,
                        appName: app,
                        title: "Doc",
                        isFloating: false
                    )
                )
            )
        }
        core.state.apply(.windowFocused(WindowID(2)))
        return core
    }

    private func apps(
        _ core: KiwiCore,
        grouping: Bool
    ) -> [SpaceBarItemView.App] {
        var look = SpaceBarLook()
        look.bar.groupAdjacentWindows = grouping
        return core.spaceBarApps(
            in: core.state.workspaces[SpaceID("1")]!,
            style: look
        ).apps
    }

    @Test("off, each window is its own glyph")
    func offDrawsOneGlyphPerWindow() {
        let core = core(apps: ["Zed", "Zed", "Finder"])
        let drawn = apps(core, grouping: false)
        #expect(drawn.map(\.name) == ["Zed", "Zed", "Finder"])
        #expect(drawn.map(\.count) == [1, 1, 1])
        #expect(drawn.map(\.focused) == [false, true, false])
    }

    @Test("on, an adjacent same-app run shares one glyph")
    func onGroupsTheRun() {
        let core = core(apps: ["Zed", "Zed", "Finder"])
        let drawn = apps(core, grouping: true)
        #expect(drawn.map(\.name) == ["Zed", "Finder"])
        #expect(drawn.map(\.count) == [2, 1])
    }

    @Test("the verb writes the setting")
    func verbWritesTheSetting() throws {
        let setting = try SpaceBarCommandSetting.parse(
            field: "group_adjacent_windows",
            args: [.bool(true)]
        ).get()
        var style = SpaceBarStyle()
        setting.apply(to: &style)
        var expected = SpaceBarStyle()
        expected.groupAdjacentWindows = true
        #expect(style == expected)
    }
}
