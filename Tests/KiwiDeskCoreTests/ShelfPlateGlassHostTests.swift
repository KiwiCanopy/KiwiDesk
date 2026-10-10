import AppKit
import Testing

@testable import KiwiDeskCore

/// The KiwiShelf plate's glass and tint ride one box host, which
/// the plate glide moves; the pair animating its own frames
/// trailed a crescent on the device (#2150).
@Suite("Shelf plate glass host", .serialized)
@MainActor
struct ShelfPlateGlassHostTests {
    /// The machine's Reduce transparency setting is a default this
    /// fixture reasons from, so it is pinned off (#660, #1374).
    init() { LiquidGlassGate.override = { false } }

    @Test("The plate's glass and tint fill the host that moves")
    func plateRidesItsHost() throws {
        guard #available(macOS 26, *) else { return }
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3, glass: true)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        var look = KiwiShelf()
        look.liquidGlass = true
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: .top,
                strip: barTitleStrip,
                shelf: look,
                sheen: 0,
                space: section,
                app: nil
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        let glass = try #require(overlay.glassPlate)
        let tint = try #require(overlay.glassTint)
        let host = try #require(GlassBox.host(of: glass))
        #expect(tint.superview === host)
        #expect(host.superview === overlay.content)
        #expect(glass.frame == host.bounds)
        #expect(tint.frame == host.bounds)
        #expect(overlay.plateBorder.frame == host.frame)
    }

    /// The plate's own call travels its host on a glide, so the
    /// shelf's plate glide reaches the box rather than landing.
    @Test("A plate glide moves the plate's host")
    func plateGlideMovesTheHost() throws {
        guard #available(macOS 26, *) else { return }
        let spaces = SpaceBarManager()
        spaces.sync([paintedSpaceBar(front: nil, spaces: 3, glass: true)])
        let section = try #require(
            spaces.shownOverlay(on: barTitleDisplay)
        )
        var look = KiwiShelf()
        look.liquidGlass = true
        let shelves = ShelfManager()
        shelves.sync([
            ShelfManager.Shelf(
                display: barTitleDisplay,
                edge: .top,
                strip: barTitleStrip,
                shelf: look,
                sheen: 0,
                space: section,
                app: nil
            )
        ])
        let overlay = try #require(
            shelves.overlayForTesting(barTitleDisplay)
        )
        let host = try #require(
            overlay.glassPlate.flatMap { GlassBox.host(of: $0) }
        )
        var writes: [(view: NSView, travels: Bool)] = []
        overlay.moveFrame = { view, frame, travels in
            writes.append((view, travels))
            view.frame = frame
        }
        var moved = host.frame
        moved.size.width -= 40
        overlay.layoutPlate(
            moved,
            edge: .top,
            shelf: look,
            sheen: 0,
            radius: 8,
            animated: true
        )
        #expect(writes.contains { $0.view === host && $0.travels })
        #expect(!host.isHidden)
    }

    /// The door every gliding glass takes: only the host travels,
    /// and the pair is written to the host's bounds before it
    /// moves, so autoresizing carries it the rest of the way.
    @Test("GlassBox.place moves the host and fills it with the pair")
    func placeMovesOnlyTheHost() throws {
        guard #available(macOS 26, *) else { return }
        let parent = NSView(
            frame: CGRect(x: 0, y: 0, width: 400, height: 40)
        )
        let box = try #require(GlassBox.make(in: parent))
        let host = try #require(GlassBox.host(of: box.glass))
        var writes: [(view: NSView, travels: Bool)] = []
        let move: BarFrameMove = { view, frame, travels in
            writes.append((view, travels))
            view.frame = frame
        }
        let place = { (frame: CGRect) in
            GlassBox.place(
                box.glass,
                tint: box.tint,
                at: frame,
                cornerRadius: 8,
                hex: "#202020B3",
                edge: .top,
                visible: true,
                animated: true,
                move: move
            )
        }
        place(CGRect(x: 10, y: 0, width: 80, height: 30))
        // A fresh host lands rather than gliding from nowhere.
        #expect(writes.last.map { $0.view === host && !$0.travels } == true)
        writes.removeAll()
        place(CGRect(x: 120, y: 0, width: 60, height: 30))
        #expect(writes.contains { $0.view === host && $0.travels })
        #expect(!writes.contains { $0.view !== host })
        #expect(box.tint.superview === host)
        #expect(box.glass.frame == host.bounds)
        #expect(box.tint.frame == host.bounds)
    }
}
