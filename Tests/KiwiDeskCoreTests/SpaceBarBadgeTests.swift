import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar state badges' driver half (#414): each item
/// slot carries its window's sticky/floating badge. Floating
/// and sticky windows never merge into a multi-window same-app
/// group (design-decisions row 97), so every badge belongs to
/// a single-window slot. Split from `SpaceBarDriverTests` for
/// the file ceiling; per-file helpers by convention.
@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
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
        core.state.setSticky(WindowID(1), .global)
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
        // Removing Mail leaves two adjacent Web windows, but
        // both hold a special state (window 1 sticky, window 3
        // floating), so they never merge into one group — each
        // stays its own slot wearing its own badge, keeping the
        // per-window state visible (design-decisions row 97).
        core.state.apply(
            .windowDestroyed(WindowID(2), wasMinimized: false)
        )
        let split = try #require(
            core.spaceBarItems(
                display: display,
                style: SpaceBarStyle()
            ).first
        )
        #expect(split.apps.map(\.name) == ["Web", "Web"])
        #expect(split.apps.map(\.sticky) == [true, false])
        #expect(split.apps.map(\.floating) == [false, true])
    }

    @Test("Sticky glyphs travel with the current space")
    func stickyGlyphTravels() throws {
        let core = seededCore()
        core.state.workspaces.assign(SpaceID("2"), to: display)
        core.state.setSticky(WindowID(1), .global)
        // On its home space: listed as a normal member.
        let home = try #require(
            core.spaceBarItems(
                display: display,
                style: SpaceBarStyle()
            ).first { $0.space == SpaceID("1") }
        )
        #expect(home.apps.map(\.name) == ["Web", "Mail"])
        #expect(home.apps.map(\.sticky) == [true, false])
        // Switch to space 2: the sticky glyph moves — it joins
        // the current item and is pruned from the home item
        // (one glyph, always where the user is).
        core.state.workspaces.activate(SpaceID("2"))
        let items = core.spaceBarItems(
            display: display,
            style: SpaceBarStyle()
        )
        let second = try #require(
            items.first { $0.space == SpaceID("2") }
        )
        #expect(second.apps.map(\.name) == ["Web"])
        #expect(second.apps.map(\.sticky) == [true])
        let first = try #require(
            items.first { $0.space == SpaceID("1") }
        )
        #expect(first.apps.map(\.name) == ["Mail"])
        // Unsticky: the glyph returns home.
        core.state.setSticky(WindowID(1), .none)
        let after = core.spaceBarItems(
            display: display,
            style: SpaceBarStyle()
        )
        let empty = try #require(
            after.first { $0.space == SpaceID("2") }
        )
        #expect(empty.apps.isEmpty)
        let restored = try #require(
            after.first { $0.space == SpaceID("1") }
        )
        #expect(
            restored.apps.map(\.name) == ["Web", "Mail"]
        )
    }

    /// The `+n` tint reads the SYSTEM focus, like the glyphs
    /// beside it: an injected ∞ traveler holds `lastFocused` and
    /// can never be the membership-guarded `space.focused`
    /// (#431), so asking the slot showed nothing at all in the
    /// one case #376's tint exists for.
    @Test("A traveler hidden past the cap tints the +n")
    func travelerFocusTintsTheOverflow() throws {
        let core = seededCore()
        core.state.workspaces.assign(SpaceID("2"), to: display)
        // Window 3 is third in its home row, so it injects at
        // index 2 — past a cap of 2.
        core.state.apply(.windowCreated(window(3, app: "Term")))
        core.state.setSticky(WindowID(3), .global)
        core.state.workspaces.activate(SpaceID("2"))
        core.state.apply(.windowCreated(window(4, app: "Note")))
        core.state.apply(.windowCreated(window(5, app: "Zed")))
        core.state.apply(.windowFocused(WindowID(4)))
        core.state.apply(.windowFocused(WindowID(3)))
        var style = SpaceBarStyle()
        style.glyphCap = 2
        let item = try #require(
            core.spaceBarItems(display: display, style: style)
                .first { $0.space == SpaceID("2") }
        )
        // The traveler is the hidden one, and it holds the
        // system focus while the Space's own slot stays on a
        // visible member.
        #expect(item.apps.map(\.name) == ["Note", "Zed"])
        #expect(item.overflow == 1)
        #expect(core.state.workspaces[SpaceID("2")]?.focused == WindowID(4))
        #expect(item.focusInOverflow)
    }
}
