import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar's multi-screen sticky half (#1214): each
/// display builds its own bar, and the question "which windows
/// are present" must still be answered with the ONE active
/// Space. The single-screen suites beside this one
/// (`SpaceBarBadgeTests`, `SpaceBarDriverTests`) cannot see the
/// defect at all — with one display, a display's shown Space and
/// the active Space are the same value. Split from the badge
/// suite for the file ceiling; per-file helpers by convention.
@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-sticky-screens-\(UUID().uuidString)"
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

@Suite("Space bar sticky across screens", .serialized)
@MainActor
struct SpaceBarStickyScreenTests {
    private let built = DisplayID(7)
    private let dell = DisplayID(8)

    /// Spaces 1 and 2 on the built-in, Space 3 on the Dell.
    /// Windows 1 (Web) and 2 (Mail) on Space 1, window 4 (Note)
    /// on Space 3. Space 1 is active, so the user is on the
    /// built-in.
    private func twoScreenCore() -> KiwiCore {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: built)
        core.state.workspaces.assign(SpaceID("2"), to: built)
        core.state.workspaces.assign(SpaceID("3"), to: dell)
        core.state.workspaces.activate(SpaceID("3"))
        core.state.apply(.windowCreated(window(4, app: "Note")))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1, app: "Web")))
        core.state.apply(.windowCreated(window(2, app: "Mail")))
        core.state.apply(.windowFocused(WindowID(2)))
        return core
    }

    private func item(
        _ core: KiwiCore,
        _ display: DisplayID,
        _ space: String,
        _ style: SpaceBarStyle = SpaceBarStyle()
    ) throws -> SpaceBarOverlay.Item {
        try #require(
            core.spaceBarItems(display: display, style: style)
                .first { $0.space == SpaceID(space) }
        )
    }

    /// The filed defect: the Dell's item for its own current
    /// Space listed the ∞ window while the layout drew it on the
    /// built-in.
    @Test("A global sticky is listed on the active screen only")
    func globalStickyStaysOnTheActiveScreen() throws {
        let core = twoScreenCore()
        core.state.setSticky(WindowID(1), .global)
        // The Dell shows Space 3, which is not the focused
        // Space, so its item lists its own window and nothing
        // else.
        let away = try item(core, dell, "3")
        #expect(away.apps.map(\.name) == ["Note"])
        #expect(away.apps.allSatisfy { !$0.sticky })
        let here = try item(core, built, "1")
        #expect(here.apps.map(\.name) == ["Web", "Mail"])
        #expect(here.apps.map(\.sticky) == [true, false])
        // Focus the Dell: the one glyph crosses with the user —
        // injected at its home index, so ahead of Note — and
        // leaves the screen it came from.
        core.state.workspaces.activate(SpaceID("3"))
        let moved = try item(core, dell, "3")
        #expect(moved.apps.map(\.name) == ["Web", "Note"])
        #expect(moved.apps.map(\.sticky) == [true, false])
        let left = try item(core, built, "1")
        #expect(left.apps.map(\.name) == ["Mail"])
    }

    /// The other half of the same verdict, and the arm that
    /// refuses the over-broad fix: pruning every sticky window
    /// from a screen the user is not on would pass the test
    /// above and silently retire 📌 (#445), whose render Space
    /// is its HOME display's shown one and never the argument.
    @Test("A screen sticky stays on its own screen's shown Space")
    func displayStickyStaysOnItsHomeScreen() throws {
        let core = twoScreenCore()
        core.state.setSticky(WindowID(1), .display)
        // Follow the user to the Dell. The 📌 window is homed on
        // the built-in, which still shows Space 1 — so its glyph
        // stays there, on the bar of a screen nobody is focused
        // on, and never joins the Dell's item.
        core.state.workspaces.activate(SpaceID("3"))
        let home = try item(core, built, "1")
        #expect(home.apps.map(\.name) == ["Web", "Mail"])
        #expect(home.apps.map(\.sticky) == [true, false])
        let away = try item(core, dell, "3")
        #expect(away.apps.map(\.name) == ["Note"])
        // Switch the built-in to Space 2: the glyph travels
        // within its own screen, and still not across.
        core.state.workspaces.activate(SpaceID("2"))
        #expect(try item(core, built, "2").apps.map(\.name) == ["Web"])
        #expect(try item(core, built, "1").apps.map(\.name) == ["Mail"])
        #expect(try item(core, dell, "3").apps.map(\.name) == ["Note"])
    }

    /// The `+n` badge tints for the SYSTEM focus hidden past the
    /// cap (#376), so only the item whose Space is the ACTIVE
    /// one may claim it — the sibling substitution three lines
    /// below the filed one, and the state that separates them is
    /// a focus still sitting on the screen the user just left.
    @Test("A second screen's +n never claims the focus")
    func overflowFocusIsTheActiveScreens() throws {
        let core = twoScreenCore()
        // Term joins the Dell's Space and takes the focus; the
        // user then moves to the built-in WITHOUT focusing
        // anything there, so the system focus is still a window
        // hidden past the Dell's cap while Space 1 is active.
        core.state.workspaces.activate(SpaceID("3"))
        core.state.apply(.windowCreated(window(5, app: "Term")))
        core.state.apply(.windowFocused(WindowID(5)))
        core.state.workspaces.activate(SpaceID("1"))
        var style = SpaceBarStyle()
        style.glyphCap = 1
        let away = try item(core, dell, "3", style)
        #expect(away.overflow == 1)
        #expect(!away.focusInOverflow)
        // Nor does the active screen claim it: the focus is not
        // behind ITS badge either, so neither bar tints.
        let here = try item(core, built, "1", style)
        #expect(here.overflow == 1)
        #expect(!here.focusInOverflow)
        // Follow the focus back to the Dell: now that Space is
        // the active one and the badge does carry the signal.
        core.state.workspaces.activate(SpaceID("3"))
        #expect(try item(core, dell, "3", style).focusInOverflow)
    }
}
