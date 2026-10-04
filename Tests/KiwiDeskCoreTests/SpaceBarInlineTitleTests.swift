import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Space Bar inline titles", .serialized)
@MainActor
struct SpaceBarInlineTitleTests {
    private let display = DisplayID(7)

    private func seededCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("inline-titles-\(UUID().uuidString)")
        )
        for space in [SpaceID("1"), SpaceID("2")] {
            core.state.workspaces.assign(space, to: display)
            core.state.workspaces.activate(space)
            for n in UInt32(1)...2 {
                let id = space == "1" ? n : n + 2
                core.state.apply(
                    .windowCreated(
                        ManagedWindow(
                            id: WindowID(id),
                            pid: 100,
                            appName: "Notes",
                            title: "Document \(id)",
                            isFloating: false
                        )
                    )
                )
            }
        }
        core.state.workspaces.activate("1")
        return core
    }

    private func items(_ core: KiwiCore, _ look: SpaceBarLook)
        -> [SpaceBarOverlay.Item]
    {
        core.spaceBarItems(display: display, style: look)
    }

    @Test("The shown Space expands windows separately on each display")
    func shownSpaceExpands() throws {
        let core = seededCore()
        var look = SpaceBarLook()
        look.expandActiveSpace = true
        let first = items(core, look)
        #expect(
            first[0].apps.map(\.inlineTitle)
                == ["Document 1", "Document 2"]
        )
        #expect(first[0].apps.allSatisfy { $0.count == 1 })
        #expect(first[1].apps.count == 1)
        #expect(first[1].apps[0].inlineTitle == nil)
        core.state.workspaces.show("2", on: display)
        let second = items(core, look)
        #expect(second[0].apps.count == 1)
        #expect(second[0].apps[0].inlineTitle == nil)
        #expect(
            second[1].apps.map(\.inlineTitle)
                == ["Document 3", "Document 4"]
        )
    }

    @Test("Hover and permanent expansion are independent")
    func independentHover() throws {
        let core = seededCore()
        var look = SpaceBarLook()
        look.groupAdjacentWindows = false
        #expect(core.spaceBars.setTitleHover("2", window: WindowID(3)))
        #expect(
            items(core, look)[1].apps.allSatisfy {
                $0.inlineTitle == nil
            }
        )
        look.showHoverTitles = true
        let hovered = items(core, look)
        #expect(hovered[0].apps.allSatisfy { $0.inlineTitle == nil })
        #expect(hovered[1].apps.map(\.inlineTitle) == ["Document 3", nil])
        core.state.apply(
            .windowTitleChanged(WindowID(3), "Updated document")
        )
        #expect(
            items(core, look)[1].apps[0].inlineTitle
                == "Updated document"
        )
        core.state.workspaces.show("2", on: display)
        #expect(
            items(core, look)[1].apps.allSatisfy {
                $0.inlineTitle == nil
            }
        )
        #expect(core.spaceBars.setTitleHover("2", window: nil))
        #expect(!core.spaceBars.setTitleHover("2", window: nil))
    }

    @Test("Groups use the app name and vertical bars retain icons")
    func groupAndVertical() throws {
        let core = seededCore()
        var look = SpaceBarLook()
        look.expandActiveSpace = true
        look.showHoverTitles = true
        _ = core.spaceBars.setTitleHover("2", window: WindowID(3))
        #expect(items(core, look)[1].apps[0].inlineTitle == "Notes")
        look.edge = .left
        #expect(
            items(core, look).allSatisfy {
                $0.apps.allSatisfy { $0.inlineTitle == nil }
            }
        )
        #expect(items(core, look)[0].apps.count == 1)
    }

    private func app(_ title: String?) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: "Notes",
            inlineTitle: title,
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: true,
            count: 1,
            windows: [WindowID(1)]
        )
    }

    private func bar(_ title: String?, look: SpaceBarLook)
        -> SpaceBarManager.Bar
    {
        SpaceBarManager.Bar(
            display: display,
            items: [
                SpaceBarOverlay.Item(
                    space: "1",
                    spaceGlyph: .text("1", tinted: true),
                    apps: [app(title)],
                    active: true,
                    after: .none
                )
            ],
            strip: CGRect(x: 0, y: 0, width: 800, height: 40),
            style: look,
            stateMarkColors: StateMarkColors(sticky: "", floating: "")
        )
    }

    @Test("Titles occupy the chip and share its window click target")
    func titleHitAndRefresh() throws {
        LiquidGlassGate.override = { false }
        let manager = SpaceBarManager()
        var picked: [WindowID] = []
        manager.glyphActions.pick = { picked = $0.windows }
        manager.sync([bar("Document", look: SpaceBarLook())])
        let overlay = try #require(manager.overlayForTesting(display))
        let chip = try #require(overlay.itemViews.first)
        chip.layoutSubtreeIfNeeded()
        let label = try #require(chip.titleViews.first)
        let target = try #require(chip.glyphTargets.first)
        #expect(!label.isHidden)
        #expect(ceil(label.cell?.cellSize.width ?? 0) <= label.frame.width)
        #expect(label.frame.maxX <= chip.bounds.maxX)
        #expect(target.frame.contains(label.frame))
        let click = chip.convert(
            CGPoint(x: label.frame.midX, y: label.frame.midY),
            to: chip.superview
        )
        #expect(chip.hitTest(click) === target)
        #expect(target.accessibilityLabel()?.contains("Document") == true)
        #expect(target.accessibilityPerformPress())
        #expect(picked == [WindowID(1)])
        #expect(manager.showsTitle(of: WindowID(1)))
        manager.sync([bar(nil, look: SpaceBarLook())])
        chip.layoutSubtreeIfNeeded()
        #expect(!manager.showsTitle(of: WindowID(1)))
        #expect(chip.titleViews[0].isHidden)
    }

    @Test("Inline title changes glide and clear when the bar hides")
    func titleGlide() throws {
        LiquidGlassGate.override = { false }
        let manager = SpaceBarManager()
        manager.sync([bar(nil, look: SpaceBarLook())])
        let overlay = try #require(manager.overlayForTesting(display))
        var travels: [Bool] = []
        overlay.moveFrame = { view, frame, animated in
            travels.append(animated)
            view.frame = frame
        }
        manager.sync([bar("Document", look: SpaceBarLook())])
        #expect(travels.contains(true))
        travels = []
        manager.sync([bar(nil, look: SpaceBarLook())])
        #expect(travels.contains(true))
        overlay.hide()
        #expect(overlay.shownInlineTitles.isEmpty)
    }
}
