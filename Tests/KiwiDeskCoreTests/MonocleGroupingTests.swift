import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// The app bar's window groups for a space, resolving the
/// grouping flag the way the live bar does (monocle override
/// over the global style).
@MainActor
private func groups(
    _ core: KiwiCore,
    in space: Space
) -> [[WindowID]] {
    core.barGroups(
        in: space,
        grouping: core.tiler.settings.monocle
            .resolvedBar(global: core.tiler.settings.appBarStyle)
            .groupAdjacentWindows
    )
}

@Suite("Monocle grouping & reorder", .serialized)
@MainActor
struct MonocleGroupingTests {
    /// A monocle space with one window per name, ids 1...n.
    private func makeNamedCore(
        _ names: [String]
    ) -> KiwiCore {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        for (index, name) in names.enumerated() {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index + 1)),
                        pid: 1,
                        appName: name
                    )
                )
            )
        }
        return core
    }

    @Test("Only adjacent same-app windows group")
    func adjacentOnly() throws {
        #expect(
            KiwiCore.adjacentRuns(
                of: ["Zed", "Zed", "Finder", "Zed"]
            ) == [0..<2, 2..<3, 3..<4]
        )
        #expect(KiwiCore.adjacentRuns(of: []).isEmpty)
        let core = makeNamedCore(
            ["Zed", "Zed", "Finder", "Zed"]
        )
        let space = try #require(core.activeSpace)
        #expect(
            groups(core, in: space) == [
                [w1, w2], [w3], [WindowID(4)],
            ]
        )
    }

    @Test("Focus inside a group expands it into single items")
    func expansion() throws {
        let core = makeNamedCore(["Zed", "Zed", "Finder"])
        core.state.workspaces.focus(w1, in: SpaceID(1))
        let space = try #require(core.activeSpace)
        #expect(
            groups(core, in: space) == [
                [w1], [w2], [w3],
            ]
        )
        // Focus leaving the group collapses it again.
        core.state.workspaces.focus(w3, in: SpaceID(1))
        let after = try #require(core.activeSpace)
        #expect(
            groups(core, in: after) == [[w1, w2], [w3]]
        )
    }

    @Test("group_adjacent_windows off: one item per window")
    func groupingOff() throws {
        let core = makeNamedCore(["Zed", "Zed"])
        #expect(
            core.execute(
                "monocle.set_app_bar_group_adjacent_windows",
                args: [.bool(false)]
            ).isSuccess
        )
        let space = try #require(core.activeSpace)
        #expect(
            groups(core, in: space) == [[w1], [w2]]
        )
    }

    @Test("Dragging an item reorders the window array")
    func moveSingle() {
        let core = makeNamedCore(["A", "B", "C"])
        core.moveBarItem(space: SpaceID(1), from: 0, to: 2)
        #expect(core.activeSpace?.windows == [w2, w3, w1])
        // Out-of-range moves are ignored.
        core.moveBarItem(space: SpaceID(1), from: 0, to: 9)
        #expect(core.activeSpace?.windows == [w2, w3, w1])
    }

    @Test("Dragging a group moves all its members together")
    func moveGroup() {
        let core = makeNamedCore(["Zed", "Zed", "Finder"])
        // Items: [Zed ×2] [Finder] — swap their slots.
        core.moveBarItem(space: SpaceID(1), from: 0, to: 1)
        #expect(core.activeSpace?.windows == [w3, w1, w2])
    }
}
