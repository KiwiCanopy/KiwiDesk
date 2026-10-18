import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space collapsed to its window count lists its apps and windows
/// in the hover peek (#1946) while the pointer rests on it (#1945,
/// always on). The run does not change, so nothing moves under the
/// pointer (#1665).
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

    private func collapsed() throws -> SpaceBarOverlay.Item {
        let core = seededCore()
        var look = SpaceBarLook()
        look.inactiveContent = .count
        let item = core.spaceBarItems(display: display, style: look)
            .first { $0.space == SpaceID("2") }
        return try #require(item)
    }

    @Test("The collapse carries its Space's windows")
    func builderCarriesTheWindows() throws {
        let item = try collapsed()
        #expect(item.collapse?.windows == 3)
        #expect(
            Set(item.collapse?.peek ?? [])
                == Set([2, 3, 4].map(WindowID.init))
        )
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
        ).collapsed(to: .count)
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

    @Test("A press on the chip closes its peek; the click switches")
    func pressOnTheChipCloses() {
        let rig = BarPeekRig()
        defer { rig.close() }
        let actions = SpaceBarGlyphActions()
        let ids = [WindowID(2), WindowID(3)]
        let view = chip(in: rig, actions: actions, peek: ids)
        view.applyHover(true, target: nil)
        rig.step()
        #expect(rig.shownTitles != nil)
        rig.peek.pressed(on: view, type: .leftMouseDown)
        #expect(rig.shownTitles == nil)
    }

    @Test("A reorder of the peeked windows moves no frame")
    func peekReorderKeepsGeometry() {
        let item = { (ids: [Int]) in
            var mail = SpaceBarItemView.App(
                name: "Mail",
                icon: nil,
                glyph: nil,
                focused: false,
                count: ids.count
            )
            mail.windows = ids.map { WindowID(UInt32($0)) }
            return SpaceBarOverlay.Item(
                space: SpaceID("2"),
                spaceGlyph: .text("2", tinted: true),
                apps: [mail],
                active: false,
                after: .none
            ).collapsed(to: .count)
        }
        let shown = { (ids: [Int]) in
            SpaceBarOverlay.Shown(
                items: [item(ids)],
                frontApp: nil,
                strip: CGRect(x: 0, y: 0, width: 400, height: 30),
                style: SpaceBarLook(),
                stateMarkColors: StateMarkColors(
                    sticky: "#ffffff",
                    floating: "#ffffff"
                )
            )
        }
        let overlay = SpaceBarOverlay()
        #expect(shown([4, 5]) != shown([5, 4]))
        #expect(overlay.keepsGeometry(shown([4, 5]), shown([5, 4])))
        #expect(!overlay.keepsGeometry(shown([4, 5]), shown([4, 5, 6])))
    }

    @Test("An empty collapsed chip peeks nothing")
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
