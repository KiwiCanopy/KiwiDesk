import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar state badges' driver half (#414): a group
/// slot aggregates its windows' sticky/floating states — an
/// "at least one" signal (badge inheritance). Split from
/// `SpaceBarDriverTests` for the file ceiling; per-file
/// helpers by convention.
@MainActor
private func makeCore() -> KiwiCore {
    KiwiCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-badges-\(UUID().uuidString)"
            )
    )
}

private func window(
    _ id: UInt32,
    app: String
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: "Doc",
        isFloating: false
    )
}

@Suite("Space bar state badges", .serialized)
@MainActor
struct SpaceBarBadgeTests {
    private let display = DisplayID(7)

    private func seededCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1, app: "Web")))
        core.state.apply(.windowCreated(window(2, app: "Mail")))
        core.state.apply(.windowFocused(WindowID(2)))
        return core
    }

    @Test("State badges aggregate over a same-app run")
    func stateBadgeAggregation() throws {
        let core = seededCore()
        // A second Web window forms a run with window 1; make
        // window 1 sticky and window 3 floating — the single
        // group slot must wear BOTH badges ("at least one").
        core.state.apply(.windowCreated(window(3, app: "Web")))
        core.state.setSticky(WindowID(1), true)
        core.state.setFloating(WindowID(3), true)
        let items = core.spaceBarItems(
            display: display,
            style: SpaceBarStyle()
        )
        let first = try #require(items.first)
        // Flat order Web, Mail, Web — adjacent runs only, so
        // the two Web windows do NOT merge across Mail.
        #expect(
            first.apps.map(\.name) == ["Web", "Mail", "Web"]
        )
        #expect(
            first.apps.map(\.sticky) == [true, false, false]
        )
        #expect(
            first.apps.map(\.floating) == [false, false, true]
        )
        // Adjacent windows of one app DO merge and aggregate.
        core.state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        let merged = try #require(
            core.spaceBarItems(
                display: display,
                style: SpaceBarStyle()
            ).first
        )
        #expect(merged.apps.map(\.name) == ["Web"])
        #expect(merged.apps.map(\.sticky) == [true])
        #expect(merged.apps.map(\.floating) == [true])
    }

    @Test("Foreign sticky windows appear on every space item")
    func foreignStickyListed() throws {
        let core = seededCore()
        core.state.workspaces.assign(SpaceID("2"), to: display)
        core.state.setSticky(WindowID(1), true)
        let items = core.spaceBarItems(
            display: display,
            style: SpaceBarStyle()
        )
        #expect(items.count == 2)
        let second = try #require(
            items.first { $0.space == SpaceID("2") }
        )
        // Space "2" has no members of its own, but the sticky
        // window is present there too — its item says so,
        // badge included (#414).
        #expect(second.apps.map(\.name) == ["Web"])
        #expect(second.apps.map(\.sticky) == [true])
        // Unsticky: the foreign listing disappears.
        core.state.setSticky(WindowID(1), false)
        let after = core.spaceBarItems(
            display: display,
            style: SpaceBarStyle()
        )
        let empty = try #require(
            after.first { $0.space == SpaceID("2") }
        )
        #expect(empty.apps.isEmpty)
    }
}
