import AppKit
import Testing

@testable import KiwiDeskCore

/// A bar joining or leaving a fused shelf never budges its
/// neighbour (#2497), in either bar order, through the real
/// drivers on a Boxed Liquid Glass shelf: the App Bar's section is
/// stood where its content was drawn, every piece inside it snaps,
/// and the shelf's glide carries it to where it ends — one motion
/// from where it was drawn to where it lands. What the animator
/// then draws is the device's. Main-actor spend: one ordered panel
/// per case.
@Suite("Shelf join and leave glide (#2497)", .serialized)
@MainActor
struct ShelfJoinLeaveGlideTests {
    /// A core with three windows in a monocle Space, both bars
    /// `auto` on the top edge in `order`, the App Bar revealed.
    private func makeCore(
        _ order: KiwiShelf.Order
    ) -> (KiwiCore, DisplayID)? {
        guard let screen = NSScreen.screens.first,
            let display = screen.kiwiDisplay
        else { return nil }
        let core = makeTestCore()
        core.shelves.ordersPanels = true
        // Pin the display rather than inherit it (#531).
        core.tiler.visibleBounds = { _ in screen.frame }
        core.state.apply(.displaysChanged([display]))
        for n in UInt32(0)..<3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(900_830 + n),
                        pid: 900_830,
                        appName: "Glide\(n)",
                        frame: CGRect(x: 100, y: 200, width: 600, height: 400)
                    )
                )
            )
        }
        core.resolveSpaceDisplays(mainID: display.id)
        if let id = core.state.workspaces.space(of: WindowID(900_830)) {
            core.state.workspaces.setMode(id, .monocle)
        }
        var settings = core.tiler.settings
        settings.spaceBarStyle.setEdge(.top)
        settings.appBarStyle.setEdge(.top)
        settings.spaceBarStyle.visibility = .auto
        settings.monocle.appBar.visibility = .auto
        settings.kiwishelf.alignment = .center
        settings.kiwishelf.order = order
        settings.kiwishelf.backgroundStyle = .boxed
        settings.kiwishelf.liquidGlass = true
        settings.animations.onExpand = true
        core.tiler.settings = settings
        NativeSpaces.currentSpaceIsUserOverride = { _ in true }
        core.updateBars()
        pinShelfGlide()
        _ = core.execute("app_bar.toggle_reveal", args: [])
        return (core, display.id)
    }

    @Test(
        "The App Bar stands where it was drawn and glides once",
        .enabled(if: NSScreen.main != nil),
        arguments: [KiwiShelf.Order.spacesFirst, .appsFirst]
    )
    func neighbourNeverBudges(order: KiwiShelf.Order) throws {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        let (core, display) = try #require(makeCore(order))
        defer { NativeSpaces.currentSpaceIsUserOverride = nil }
        let app = try #require(core.appBars.shownOverlay(on: display))
        let overlay = try #require(
            core.shelves.overlayForTesting(display, edge: .top)
        )
        defer { overlay.hide() }
        var travelled: [String] = []
        app.moveFrame = { view, frame, animated in
            if animated { travelled.append("\(type(of: view))") }
            view.frame = frame
        }
        let recorder = Recorder(app: app, strip: overlay.stripView)
        let drawnX = { recorder.drawnX() }
        app.root.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            recorder,
            selector: #selector(Recorder.rootMoved),
            name: NSView.frameDidChangeNotification,
            object: app.root
        )
        defer { NotificationCenter.default.removeObserver(recorder) }
        for step in ["join", "leave"] {
            let before = try #require(drawnX())
            recorder.placed = []
            travelled = []
            #expect(
                core.execute("space_bar.toggle_reveal", args: []).isSuccess
            )
            let after = try #require(drawnX())
            // The stand, then the glide's target: nothing between.
            try #require(recorder.placed.count == 2, "\(order) \(step)")
            #expect(abs(recorder.placed[0] - before) < 0.5, "\(order) \(step)")
            #expect(abs(recorder.placed[1] - after) < 0.5, "\(order) \(step)")
            #expect(travelled.isEmpty, "\(order) \(step): \(travelled)")
        }
    }

    /// Where the App Bar's first item is drawn, read at every write
    /// of its section's frame.
    @MainActor
    final class Recorder: NSObject {
        let app: AppBarOverlay
        let strip: NSView
        var placed: [CGFloat] = []

        init(app: AppBarOverlay, strip: NSView) {
            self.app = app
            self.strip = strip
        }

        func drawnX() -> CGFloat? {
            app.itemViews.first.map {
                $0.convert($0.bounds, to: strip).minX
            }
        }

        @objc func rootMoved() {
            drawnX().map { placed.append($0) }
        }
    }
}
