import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.inactive_content` (#1683): a Space its screen does
/// not show draws its apps, its window count or its identifier
/// alone. The collapse is decided once, in the item the builder
/// returns, so the shelf plan and the render measure one run.
@MainActor
private func makeCore() -> KiwiCore {
    makeTestCore(
        configDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-inactive-content-\(UUID().uuidString)"
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

@Suite("Space bar inactive content", .serialized)
@MainActor
struct SpaceBarInactiveContentTests {
    private let display = DisplayID(7)
    private let dell = DisplayID(8)

    /// Space 1 shown with one window; Space 2 holds three, one
    /// floating; Space 3 is empty.
    private func seededCore() -> KiwiCore {
        let core = makeCore()
        for n in 1...3 {
            core.state.workspaces.assign(SpaceID("\(n)"), to: display)
        }
        core.state.workspaces.activate(SpaceID("2"))
        core.state.apply(.windowCreated(window(2, app: "Mail")))
        core.state.apply(.windowCreated(window(3, app: "Mail")))
        core.state.apply(.windowCreated(window(4, app: "Web")))
        core.state.setFloating(WindowID(3), true)
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1, app: "Notes")))
        core.state.apply(.windowFocused(WindowID(1)))
        return core
    }

    private func items(
        _ core: KiwiCore,
        _ content: SpaceBarStyle.InactiveContent,
        display: DisplayID? = nil,
        hideEmpty: Bool = false
    ) -> [SpaceID: SpaceBarOverlay.Item] {
        var look = SpaceBarLook()
        look.inactiveContent = content
        look.hideEmpty = hideEmpty
        let built = core.spaceBarItems(
            display: display ?? self.display,
            style: look
        )
        return Dictionary(
            uniqueKeysWithValues: built.compactMap { item in
                item.space.map { ($0, item) }
            }
        )
    }

    @Test("Apps is the default and collapses nothing")
    func appsIsTheDefault() throws {
        #expect(SpaceBarStyle().inactiveContent == .apps)
        let built = items(seededCore(), .apps)
        let other = try #require(built[SpaceID("2")])
        #expect(other.collapse == nil)
        #expect(other.apps.map(\.name) == ["Mail", "Mail", "Web"])
    }

    @Test("Window count keeps the identifier and the count")
    func countCollapsesTheOthers() throws {
        let built = items(seededCore(), .count)
        let other = try #require(built[SpaceID("2")])
        #expect(other.collapse == .count(windows: 3))
        // The glyphs and their state badges go; the count is the
        // `+n` badge's unit, windows, and `overflow` keeps its
        // one meaning.
        #expect(other.apps.isEmpty)
        #expect(other.overflow == 0)
        #expect(other.badgeCount == 3)
        let empty = try #require(built[SpaceID("3")])
        #expect(empty.badgeCount == 0)
        let shown = try #require(built[SpaceID("1")])
        #expect(shown.collapse == nil)
        #expect(shown.apps.map(\.name) == ["Notes"])
    }

    @Test("Minimal keeps the identifier and remembers the count")
    func identifierCollapsesTheOthers() throws {
        let built = items(seededCore(), .identifier)
        let other = try #require(built[SpaceID("2")])
        #expect(other.collapse == .identifier(windows: 3))
        #expect(other.apps.isEmpty)
        #expect(other.overflow == 0)
        let empty = try #require(built[SpaceID("3")])
        #expect(empty.collapse == .identifier(windows: 0))
        #expect(try #require(built[SpaceID("1")]).collapse == nil)
    }

    /// A second collapse keeps the first's count rather than
    /// recounting the glyphs the first one dropped.
    @Test(
        "Collapsing twice is collapsing once",
        arguments: [
            SpaceBarStyle.InactiveContent.count, .identifier,
        ]
    )
    func collapseIsIdempotent(
        content: SpaceBarStyle.InactiveContent
    ) throws {
        let built = items(seededCore(), content)
        let once = try #require(built[SpaceID("2")])
        let twice = once.collapsed(to: content)
        #expect(twice.collapse == once.collapse)
        #expect(twice.collapse?.windows == 3)
        #expect(twice.badgeCount == once.badgeCount)
    }

    /// The layer item is never a Space, so it never collapses.
    @Test("A layer item passes unchanged")
    func layerPasses() {
        let layer = SpaceBarOverlay.Item(
            layer: "L",
            glyph: .text("L", tinted: false)
        )
        #expect(layer.collapsed(to: .identifier).collapse == nil)
    }

    /// `hide_empty` reads the glyphs the collapse drops, so it
    /// runs first: an occupied Space stays listed.
    @Test("Hide empty judges before the collapse")
    func hideEmptyJudgesFirst() {
        let built = items(seededCore(), .identifier, hideEmpty: true)
        #expect(built[SpaceID("2")] != nil)
        #expect(built[SpaceID("3")] == nil)
    }

    /// Per display: the expanded Space is the one each screen
    /// SHOWS, not the focused one.
    @Test("Each screen expands the Space it shows")
    func eachScreenExpandsItsShownSpace() throws {
        let core = makeCore()
        core.state.workspaces.assign(SpaceID("1"), to: display)
        core.state.workspaces.assign(SpaceID("3"), to: dell)
        core.state.workspaces.activate(SpaceID("3"))
        core.state.apply(.windowCreated(window(4, app: "Note")))
        core.state.workspaces.activate(SpaceID("1"))
        core.state.apply(.windowCreated(window(1, app: "Web")))
        let away = try #require(
            items(core, .identifier, display: dell)[SpaceID("3")]
        )
        #expect(away.collapse == nil)
        #expect(away.apps.map(\.name) == ["Note"])
    }

    @Test("A switch glides the items only where others collapse")
    func glideDecision() {
        let one = SpaceID("1")
        let two = SpaceID("2")
        let glide = {
            (
                content: SpaceBarStyle.InactiveContent,
                from: SpaceID?,
                to: SpaceID?,
                same: Bool
            ) in
            SpaceBarOverlay.itemsGlide(
                content: content,
                from: from,
                to: to,
                sameItems: same
            )
        }
        #expect(glide(.count, one, two, true))
        #expect(glide(.identifier, one, two, true))
        #expect(!glide(.apps, one, two, true))
        #expect(!glide(.count, one, one, true))
        // A first render appears rather than moving.
        #expect(!glide(.count, nil, two, true))
        // Other items drawn: pooled views would slide between
        // different Spaces' slots.
        #expect(!glide(.identifier, one, two, false))
    }
}
