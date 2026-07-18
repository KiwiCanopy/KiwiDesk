import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

private func window(
    _ id: UInt32,
    app: String = "TestApp"
) -> ManagedWindow {
    ManagedWindow(
        id: WindowID(id),
        pid: 100,
        appName: app,
        title: "Doc",
        isFloating: false
    )
}

/// The decision-bearing driver behaviors (#293): item building
/// (profile order, hide_empty's keep-current exception, active
/// and focused flags) and the identifier fallback ladder.
@Suite("Space bar driver", .serialized)
@MainActor
struct SpaceBarDriverTests {
    private let display = DisplayID(7)

    /// Three spaces on one display; windows land in space "1".
    private func seededCore() -> KiwiCore {
        let core = makeCore()
        for space in ["1", "2", "3"] {
            core.state.workspaces.assign(
                SpaceID(space),
                to: display
            )
        }
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1, app: "Web")))
        core.state.apply(.windowCreated(window(2, app: "Mail")))
        core.state.apply(.windowFocused(WindowID(2)))
        return core
    }

    @Test("Items follow profile order with active/focused flags")
    func itemBuilding() throws {
        let core = seededCore()
        let items = core.spaceBarItems(
            display: display,
            style: SpaceBarStyle()
        )
        #expect(
            items.map(\.space) == [
                SpaceID("1"), SpaceID("2"), SpaceID("3"),
            ]
        )
        let first = try #require(items.first)
        #expect(first.active)
        #expect(items[1].active == false)
        #expect(first.apps.map(\.name) == ["Web", "Mail"])
        #expect(first.apps.map(\.focused) == [false, true])
        #expect(items[1].apps.isEmpty)
    }

    @Test("hide_empty drops empty spaces except the current one")
    func hideEmpty() {
        let core = seededCore()
        var style = SpaceBarStyle()
        style.hideEmpty = true
        // Active space "1" has windows: "2"/"3" are empty and
        // not current → dropped.
        #expect(
            core.spaceBarItems(display: display, style: style)
                .map(\.space) == [SpaceID("1")]
        )
        // An empty CURRENT space always stays (cold start must
        // not collapse the strip).
        core.state.workspaces.activate(SpaceID("2"))
        #expect(
            core.spaceBarItems(display: display, style: style)
                .map(\.space) == [SpaceID("1"), SpaceID("2")]
        )
    }

    @Test("Adjacent same-app runs group; non-adjacent stay")
    func grouping() throws {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        for (id, app) in [
            (1, "Zed"), (2, "Zed"), (3, "Finder"), (4, "Zed"),
        ] {
            core.state.apply(
                .windowCreated(window(UInt32(id), app: app))
            )
        }
        // Focus a member of the leading run: the group takes
        // the focused flag, and stays collapsed (no expansion).
        core.state.apply(.windowFocused(WindowID(1)))
        let (apps, overflow) = core.spaceBarApps(
            in: core.state.workspaces[SpaceID("1")]!,
            style: SpaceBarStyle()
        )
        #expect(overflow == 0)
        #expect(apps.map(\.name) == ["Zed", "Finder", "Zed"])
        #expect(apps.map(\.count) == [2, 1, 1])
        #expect(apps.map(\.focused) == [true, false, false])
    }

    @Test("Groups past the cap collapse into the +n overflow")
    func overflowCap() throws {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        // 7 apps → 7 groups; cap 5 → 2 hidden groups of two
        // windows each, so n counts WINDOWS (4), not slots (2).
        for id in 1...6 {
            core.state.apply(
                .windowCreated(
                    window(UInt32(id), app: "App\(id)")
                )
            )
        }
        core.state.apply(
            .windowCreated(window(7, app: "App6"))
        )
        core.state.apply(
            .windowCreated(window(8, app: "App7"))
        )
        core.state.apply(
            .windowCreated(window(9, app: "App7"))
        )
        let (apps, overflow) = core.spaceBarApps(
            in: core.state.workspaces[SpaceID("1")]!,
            style: SpaceBarStyle()
        )
        #expect(apps.count == 5)
        #expect(overflow == 4)
    }

    @Test("glyph_cap drives the visible/overflow split (#376)")
    func glyphCapAdjustable() throws {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.activate(SpaceID("1"))
        // 6 distinct apps → 6 single-window groups.
        for id in 1...6 {
            core.state.apply(
                .windowCreated(window(UInt32(id), app: "App\(id)"))
            )
        }
        let space = core.state.workspaces[SpaceID("1")]!
        // A lower cap shows fewer glyphs, hides the rest as
        // WINDOWS in the +n badge.
        var low = SpaceBarStyle()
        low.glyphCap = 2
        let capped = core.spaceBarApps(in: space, style: low)
        #expect(capped.apps.count == 2)
        #expect(capped.overflow == 4)
        // An out-of-range cap clamps via resolvedGlyphCap: 0 → 1,
        // and a cap past the group count shows all with no badge.
        var floored = SpaceBarStyle()
        floored.glyphCap = 0
        #expect(
            core.spaceBarApps(in: space, style: floored)
                .apps.count == 1
        )
        var wide = SpaceBarStyle()
        wide.glyphCap = 99
        let all = core.spaceBarApps(in: space, style: wide)
        #expect(all.apps.count == 6)
        #expect(all.overflow == 0)
    }

    @Test("Front segment follows the toggle and the focus")
    func frontSegment() throws {
        let core = seededCore()
        // Toggle off → nil.
        #expect(
            core.frontApp(
                display: display,
                style: SpaceBarStyle()
            ) == nil
        )
        // Toggle on → the focused window's app ("Mail").
        var style = SpaceBarStyle()
        style.showFrontApp = true
        let app = core.frontApp(display: display, style: style)
        #expect(app?.name == "Mail")
        #expect(app?.count == 1)
    }

    @Test("Identifier ladder: icon, symbol probe, monogram")
    func identifierLadder() {
        let core = makeCore()
        // Configured SF Symbol wins.
        core.tiler.settings.spaceIcons[SpaceID("1")] = "globe"
        #expect(
            core.spaceIdentifier(for: SpaceID("1"))
                == .symbol("globe")
        )
        // Configured emoji renders untinted; VS16 emoji too.
        core.tiler.settings.spaceIcons[SpaceID("2")] = "🥝"
        #expect(
            core.spaceIdentifier(for: SpaceID("2"))
                == .text("🥝", tinted: false)
        )
        core.tiler.settings.spaceIcons[SpaceID("3")] = "☀️"
        #expect(
            core.spaceIdentifier(for: SpaceID("3"))
                == .text("☀️", tinted: false)
        )
        // A plain character tints with the state color.
        core.tiler.settings.spaceIcons[SpaceID("4")] = "K"
        #expect(
            core.spaceIdentifier(for: SpaceID("4"))
                == .text("K", tinted: true)
        )
        // Unconfigured numeric id → N.square while the symbol
        // exists…
        #expect(
            core.spaceIdentifier(for: SpaceID("5"))
                == .symbol("5.square")
        )
        // …and falls to the monogram past the symbol range.
        #expect(
            core.spaceIdentifier(for: SpaceID("99"))
                == .text("99", tinted: true)
        )
        // Named space → two-letter uppercase monogram.
        #expect(
            core.spaceIdentifier(for: SpaceID("mail"))
                == .text("MA", tinted: true)
        )
    }
}

/// The same-edge info-row predicate (#293): true only while
/// the Space Bar and at least one ENABLED layout App Bar
/// resolve to the same edge — per-layout enablement and edge
/// overrides both count.
@Suite("Space bar same-edge predicate")
struct SpaceBarSameEdgeTests {
    @Test("Predicate honors enablement and overrides")
    func predicate() {
        var settings = TilingSettings()
        // Space Bar off → never.
        #expect(!settings.spaceBarSharesEdgeWithAppBar)
        settings.spaceBarStyle.enabled = true
        // Defaults: space left, app bars top → no.
        #expect(!settings.spaceBarSharesEdgeWithAppBar)
        // Global App Bar moves to left → yes.
        settings.appBarStyle.edge = .left
        #expect(settings.spaceBarSharesEdgeWithAppBar)
        // Both layout bars disabled → the App Bar exists
        // nowhere, so no.
        settings.monocle.appBar.enabled = false
        settings.scrolling.appBar.enabled = false
        #expect(!settings.spaceBarSharesEdgeWithAppBar)
        // One layout re-enabled with a DIVERGING override → no;
        // override matching the space edge → yes.
        settings.monocle.appBar.enabled = true
        settings.monocle.appBar.edge = .top
        #expect(!settings.spaceBarSharesEdgeWithAppBar)
        settings.monocle.appBar.edge = .left
        #expect(settings.spaceBarSharesEdgeWithAppBar)
    }
}

/// Stacked top strips (#293): the float clamp composes — the
/// space bar strip pushes first, the app bar strip (carved
/// below it) pushes further.
@Suite("Combined top-strip float clamp")
struct CombinedClampTests {
    @Test("A float clears both stacked strips")
    func stackedStrips() {
        let visible = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        var space = SpaceBarStyle()
        space.enabled = true
        space.edge = .top
        let spaceStrip = SpaceBarGeometry.strip(
            in: visible,
            style: space
        )!
        let remaining = SpaceBarGeometry.remainingFrame(
            in: visible,
            style: space
        )
        let appStrip = AppBarGeometry.barFrame(
            in: remaining,
            edge: .top,
            thickness: 32
        )
        let float = CGRect(x: 10, y: 5, width: 400, height: 300)
        var clamped = AppBarGeometry.clampBelowTopStrip(
            float,
            strip: spaceStrip
        )
        clamped = AppBarGeometry.clampBelowTopStrip(
            clamped,
            strip: appStrip
        )
        // Below the combined reservation: 32 + 32.
        #expect(clamped.minY == 64)
        #expect(clamped.size == float.size)
    }
}
