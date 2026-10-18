import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `space_bar.peek_on_hover` (#1945): a Space collapsed to its
/// window count lists its apps and windows in the hover peek
/// (#1946) while the pointer rests on it, off by default. The run
/// does not change, so nothing moves under the pointer (#1665).
@Suite("Space bar collapsed peek", .serialized)
@MainActor
struct SpaceBarCollapsedPeekTests {
    private let display = DisplayID(7)

    /// Space 1 shown; Space 2 holds Mail twice and Web once.
    private func seededCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-peek-\(UUID().uuidString)")
        )
        for n in 1...2 {
            core.state.workspaces.assign(SpaceID("\(n)"), to: display)
        }
        core.state.workspaces.activate(SpaceID("2"))
        for (id, app) in [(2, "Mail"), (3, "Web"), (4, "Mail")] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 100,
                        appName: app,
                        title: "Doc",
                        isFloating: false
                    )
                )
            )
        }
        core.state.workspaces.activate(SpaceID("1"))
        return core
    }

    private func collapsed(peeking: Bool) throws -> SpaceBarOverlay.Item {
        let core = seededCore()
        var look = SpaceBarLook()
        look.inactiveContent = .count
        look.peekOnHover = peeking
        let item = core.spaceBarItems(display: display, style: look)
            .first { $0.space == SpaceID("2") }
        return try #require(item)
    }

    @Test("The collapse carries its Space's windows only when on")
    func builderCarriesTheWindows() throws {
        let on = try collapsed(peeking: true)
        #expect(on.collapse?.windows == 3)
        #expect(
            Set(on.collapse?.peek ?? [])
                == Set([2, 3, 4].map(WindowID.init))
        )
        let off = try collapsed(peeking: false)
        #expect(off.collapse?.windows == 3)
        #expect(off.collapse?.peek == [])
    }

    @Test("The collapse lists before, the glyphs, then after")
    func peekKeepsTheStripOrder() {
        var mail = SpaceBarItemView.App(
            name: "Mail",
            icon: nil,
            glyph: nil,
            focused: false,
            count: 1
        )
        mail.windows = [WindowID(5)]
        let item = SpaceBarOverlay.Item(
            space: SpaceID("2"),
            spaceGlyph: .text("2", tinted: true),
            apps: [mail],
            active: false,
            before: .init(windows: [WindowID(4)]),
            after: .init(windows: [WindowID(6)])
        ).collapsed(to: .count, peeking: true)
        #expect(item.collapse?.peek == [4, 5, 6].map(WindowID.init))
    }

    /// The item holds its actions weakly, so the caller keeps them.
    private func chip(
        in rig: BarPeekRig,
        actions: SpaceBarGlyphActions,
        peek: [WindowID]
    ) -> SpaceBarItemView {
        let view = SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: 60, height: 40)
        )
        rig.window.contentView?.addSubview(view)
        actions.peek = rig.peek
        view.glyphActions = actions
        view.configure(
            identity: .space(SpaceID("2")),
            spaceGlyph: .text("2", tinted: true),
            apps: [],
            active: false,
            horizontal: true,
            style: SpaceBarLook(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            collapse: .init(windows: peek.count, peek: peek)
        )
        view.layout()
        return view
    }

    @Test("Resting on a collapsed chip peeks its windows")
    func hoverPeeksTheSpace() {
        let rig = BarPeekRig()
        defer { rig.close() }
        let ids = [WindowID(2), WindowID(3)]
        let actions = SpaceBarGlyphActions()
        let view = chip(in: rig, actions: actions, peek: ids)
        #expect(view.collapsedPeek == .space(ids))
        view.applyHover(true, target: nil)
        rig.step()
        #expect(rig.shownTitles == ["Window 2", "Window 3"])
    }

    @Test("With the toggle off a collapsed chip peeks nothing")
    func offPeeksNothing() {
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = SpaceBarGlyphActions()
        let view = chip(in: rig, actions: actions, peek: [])
        #expect(view.collapsedPeek == nil)
        view.applyHover(true, target: nil)
        rig.step()
        #expect(rig.shownTitles == nil)
    }
}
