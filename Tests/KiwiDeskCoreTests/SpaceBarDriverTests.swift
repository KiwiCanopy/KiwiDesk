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
