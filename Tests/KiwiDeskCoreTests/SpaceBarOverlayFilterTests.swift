import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A transient overlay draws no Space Bar glyph (#683) — the same
/// draw-time decision the focus ring makes (#300), one surface
/// over. The filter runs BEFORE the same-app grouping and the
/// glyph cap, so an overlay can neither split a run nor eat a
/// capped slot. Split from `SpaceBarDriverTests` for the file
/// ceiling; per-file helpers by convention.
@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-overlay-\(UUID().uuidString)"
            )
    )
}

private func window(
    _ id: UInt32,
    app: String,
    overlay: Bool = false
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: "Doc",
        isFloating: overlay,
        isTransientOverlay: overlay
    )
}

@Suite("Space bar overlay filter", .serialized)
@MainActor
struct SpaceBarOverlayFilterTests {
    private let display = DisplayID(7)

    private func seededCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        return core
    }

    @Test("A popup's transient windows draw no glyph")
    func overlaysAreNotDrawn() throws {
        let core = seededCore()
        core.state.apply(.windowCreated(window(1, app: "Chat")))
        core.state.apply(.windowCreated(window(2, app: "Mail")))
        let before = try #require(
            core.spaceBarItems(
                display: display,
                style: SpaceBarStyle()
            ).first
        )
        #expect(before.apps.map(\.name) == ["Chat", "Mail"])
        // The context menu and its submenu surface as AX windows
        // of the same app — members of the space, but never the
        // user's idea of "the app's windows".
        core.state.apply(
            .windowCreated(window(3, app: "Chat", overlay: true))
        )
        core.state.apply(
            .windowCreated(window(4, app: "Chat", overlay: true))
        )
        let item = try #require(
            core.spaceBarItems(
                display: display,
                style: SpaceBarStyle()
            ).first
        )
        #expect(item.apps.map(\.name) == ["Chat", "Mail"])
        // Nor do they earn the floating badge they used to wear.
        #expect(item.apps.map(\.floating) == [false, false])
        #expect(item.overflow == 0)
    }

    @Test("An overlay neither splits a run nor eats a cap slot")
    func groupingAndCapRunAfterTheFilter() throws {
        let core = seededCore()
        var style = SpaceBarStyle()
        style.glyphCap = 2
        // Flat order: Web, overlay(Web), Web, Mail — pinned
        // rather than left to spawn placement, since the claim
        // is about an overlay sitting BETWEEN two same-app
        // windows. Dropped, the two Web windows are adjacent and
        // merge into ONE slot of count 2 — and the cap then
        // still has room for Mail, leaving nothing hidden.
        core.state.apply(.windowCreated(window(1, app: "Web")))
        core.state.apply(
            .windowCreated(window(2, app: "Web", overlay: true))
        )
        core.state.apply(.windowCreated(window(3, app: "Web")))
        core.state.apply(.windowCreated(window(4, app: "Mail")))
        core.state.workspaces.withSpace(SpaceID("1")) {
            $0.windows = [
                WindowID(1), WindowID(2), WindowID(3),
                WindowID(4),
            ]
        }
        let item = try #require(
            core.spaceBarItems(display: display, style: style)
                .first
        )
        #expect(item.apps.map(\.name) == ["Web", "Mail"])
        #expect(item.apps.map(\.count) == [2, 1])
        #expect(item.overflow == 0)
    }

    @Test("The +n badge never counts an undrawn overlay")
    func overflowCountsDrawnWindowsOnly() throws {
        let core = seededCore()
        var style = SpaceBarStyle()
        style.glyphCap = 1
        core.state.apply(.windowCreated(window(1, app: "Web")))
        core.state.apply(.windowCreated(window(2, app: "Mail")))
        core.state.apply(
            .windowCreated(window(3, app: "Mail", overlay: true))
        )
        let item = try #require(
            core.spaceBarItems(display: display, style: style)
                .first
        )
        #expect(item.apps.map(\.name) == ["Web"])
        // Mail alone is hidden: the overlay is not a window the
        // "+n" promises the user can reach.
        #expect(item.overflow == 1)
    }

    @Test("A space holding only overlays reads as empty")
    func hideEmptySeesThroughOverlays() throws {
        let core = seededCore()
        core.state.workspaces.assign(SpaceID("2"), to: display)
        var style = SpaceBarStyle()
        style.hideEmpty = true
        core.state.apply(.windowCreated(window(1, app: "Web")))
        core.state.workspaces.activate(SpaceID("2"))
        core.state.apply(
            .windowCreated(window(2, app: "Web", overlay: true))
        )
        core.state.workspaces.activate(SpaceID("1"))
        let spaces = core.spaceBarItems(
            display: display,
            style: style
        ).map(\.space)
        #expect(spaces == [SpaceID("1")])
    }
}
