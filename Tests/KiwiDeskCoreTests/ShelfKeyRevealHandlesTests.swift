import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A bar its key reveals leaves every other handle on its edge live
/// (#3512): the sibling's handle stays where it rests, a hover on it
/// opens that bar beside the pinned one, and the Pocket's handle
/// keeps its slot. Only a hover reveal makes the sibling stand aside
/// (#761). Both bars and the Pocket rest as handles on the top edge.
@Suite("Key reveal keeps the handles (#3512)", .serialized)
@MainActor
struct ShelfKeyRevealHandlesTests {
    private static let window = WindowID(900_763)

    /// Scheduled revealer timers, run by hand.
    private final class Timers {
        var queue: [(body: @MainActor () -> Void, live: Bool)] = []

        @MainActor func drain() {
            var index = 0
            while index < queue.count {
                if queue[index].live {
                    queue[index].live = false
                    queue[index].body()
                }
                index += 1
            }
        }
    }

    private final class Pointer {
        var point = CGPoint.zero
    }

    @MainActor private struct Rig {
        let core: KiwiCore
        let shelf: ShelfManager.Key
        let timers: Timers
        let pointer: Pointer

        var space: ShelfRevealer.Key { .init(shelf: shelf, bar: .space) }
        var app: ShelfRevealer.Key { .init(shelf: shelf, bar: .app) }
        var reveal: ShelfRevealer { core.shelves.reveal }

        @MainActor func spec(_ bar: ShelfBar) -> ShelfHandleSpec? {
            core.shelves.handles.handleForTesting(
                .init(shelf: shelf, bar: bar)
            )?.view.spec
        }
    }

    private func rig() -> Rig? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: Self.window,
                    pid: 900_763,
                    appName: "KeyRevealApp",
                    frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                )
            )
        )
        core.resolveSpaceDisplays(mainID: display.id)
        if let id = core.state.workspaces.space(of: Self.window) {
            core.state.workspaces.setMode(id, .monocle)
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.kiwishelf.pocketEdges.setEdge(.top)
        settings.kiwishelf.pocketVisibility = .auto
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .auto
        settings.kiwishelf.revealTimeout = 0
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        let timers = Timers()
        let pointer = Pointer()
        let reveal = core.shelves.reveal
        reveal.location = { pointer.point }
        reveal.schedule = { _, body in
            let index = timers.queue.count
            timers.queue.append((body, true))
            return ShelfRevealTimer(onCancel: {
                timers.queue[index].live = false
            })
        }
        reveal.onChange = { [weak core] in core?.updateBars() }
        core.updateBars()
        return Rig(
            core: core,
            shelf: ShelfManager.Key(display: display.id, edge: .top),
            timers: timers,
            pointer: pointer
        )
    }

    @Test(
        "a key pin leaves the sibling's handle live, a hover does not",
        .enabled(if: NSScreen.main != nil)
    )
    func keyPinKeepsTheSibling() throws {
        let rig = try #require(rig())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(
            rig.core.execute("space_bar.toggle_reveal", args: []).isSuccess
        )
        #expect(rig.reveal.reveal(of: rig.space) == .pinned(until: nil))
        let app = try #require(rig.spec(.app))
        #expect(!app.yields)
        #expect(!app.standsAside)
        #expect(!rig.reveal.yields(rig.app))
        // Control: the same bar shown by hover stands the sibling
        // aside.
        rig.reveal.set(.hover, for: rig.space)
        rig.core.updateBars()
        #expect(rig.reveal.yields(rig.app))
        #expect(rig.spec(.app)?.yields == true)
    }

    @Test(
        "a hover beside a pinned bar opens that bar",
        .enabled(if: NSScreen.main != nil)
    )
    func hoverOpensBesideThePin() throws {
        let rig = try #require(rig())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        #expect(
            rig.core.execute("space_bar.toggle_reveal", args: []).isSuccess
        )
        let target = try #require(rig.reveal.targets[rig.app])
        let approach = try #require(target.approach)
        let tab = try #require(target.handle)
        let point = CGPoint(x: tab.midX, y: tab.midY)
        #expect(approach.contains(point))
        rig.pointer.point = point
        rig.reveal.moved(to: point)
        rig.timers.drain()
        #expect(rig.reveal.reveal(of: rig.app) == .hover)
        #expect(rig.reveal.reveal(of: rig.space) == .pinned(until: nil))
        #expect(!rig.core.spaceBars.shownStrips.isEmpty)
        #expect(!rig.core.appBars.shownStrips.isEmpty)
    }

    @Test(
        "a second press hides its own bar alone",
        .enabled(if: NSScreen.main != nil)
    )
    func secondPressHidesItsOwn() throws {
        let rig = try #require(rig())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        for verb in ["app_bar", "space_bar", "space_bar"] {
            #expect(
                rig.core.execute("\(verb).toggle_reveal", args: [])
                    .isSuccess
            )
        }
        #expect(rig.reveal.reveal(of: rig.space) == .hidden)
        #expect(rig.reveal.reveal(of: rig.app) == .pinned(until: nil))
        let space = try #require(rig.spec(.space))
        #expect(!space.standsAside)
    }

    @Test(
        "the Pocket's handle keeps its slot through a key reveal",
        .enabled(if: NSScreen.main != nil)
    )
    func pocketKeepsItsSlot() throws {
        let rig = try #require(rig())
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let display = rig.shelf.display
        let rest = try #require(rig.core.pocketPlate.specs[display])
        #expect(rig.core.pocketPlace(on: display) == .handle)
        for verb in ["space_bar", "app_bar"] {
            #expect(
                rig.core.execute("\(verb).toggle_reveal", args: [])
                    .isSuccess
            )
            #expect(rig.core.pocketPlace(on: display) == .handle)
            #expect(rig.core.pocketPlate.specs[display] == rest)
            let pocket = rig.core.pocketApproachKey(on: display)
            #expect(rig.reveal.targets[pocket] != nil)
        }
    }
}
