import AppKit
import Testing

@testable import KiwiDeskCore

/// The App Bar's first render after a hide LANDS its run and its
/// items (#1838): a section appearing on a shelf would otherwise
/// slide its row in from wherever it last sat, on top of the
/// shelf's own fade or grow. A later render travels as before.
@Suite("App Bar landing", .serialized)
@MainActor
struct AppBarLandingTests {
    private func item(_ id: UInt32) -> AppBarOverlay.Item {
        AppBarOverlay.Item(id: WindowID(id), text: "App\(id)", icon: nil)
    }

    private func show(_ overlay: AppBarOverlay, _ items: [AppBarOverlay.Item])
    {
        overlay.show(
            items: items,
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 900, height: 30),
            style: AppBarLook()
        )
    }

    @Test("The first render after a hide lands; the next travels")
    func firstRenderLands() {
        let overlay = AppBarOverlay()
        var travels: [Bool] = []
        overlay.moveFrame = { view, frame, animated in
            travels.append(animated)
            view.frame = frame
        }
        show(overlay, [item(1), item(2)])
        #expect(!travels.isEmpty)
        #expect(travels.allSatisfy { !$0 })
        travels = []
        show(overlay, [item(1), item(2), item(3)])
        #expect(!travels.isEmpty)
        #expect(travels.allSatisfy { $0 })
        overlay.hide()
        travels = []
        show(overlay, [item(1)])
        #expect(!travels.isEmpty)
        #expect(travels.allSatisfy { !$0 })
    }

    /// A new slot is the shelf's to glide (#761): the run snaps to
    /// the content the shelf measured, as the Space Bar's does, so
    /// the section's glide and the run's never add up — the App
    /// Bar jumped aside when the Space Bar left a fused shelf.
    @Test("A render into a new slot snaps the run")
    func newSlotSnapsTheRun() {
        let overlay = AppBarOverlay()
        var runMoves: [Bool] = []
        overlay.moveFrame = { view, frame, animated in
            if view === overlay.itemRun { runMoves.append(animated) }
            view.frame = frame
        }
        let items = [item(1), item(2)]
        show(overlay, items)
        runMoves = []
        overlay.show(
            items: items,
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 300, height: 30),
            style: AppBarLook()
        )
        #expect(runMoves == [false])
        // The same slot again travels, as a scroll-follow does.
        runMoves = []
        overlay.show(
            items: items + [item(3)],
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 300, height: 30),
            style: AppBarLook()
        )
        #expect(runMoves == [true])
    }

    /// Its items snap too: a re-centred row gliding inside the
    /// section the shelf glides swung the bar left, then right,
    /// when the Space Bar left a fused shelf (device, 2026-10-20).
    @Test("A render into a new slot snaps the items")
    func newSlotSnapsTheItems() {
        let overlay = AppBarOverlay()
        var itemMoves: [Bool] = []
        overlay.moveFrame = { view, frame, animated in
            if view.superview === overlay.itemRun {
                itemMoves.append(animated)
            }
            view.frame = frame
        }
        let items = [item(1), item(2)]
        show(overlay, items)
        itemMoves = []
        overlay.show(
            items: items,
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 300, height: 30),
            style: AppBarLook()
        )
        #expect(!itemMoves.isEmpty)
        #expect(!itemMoves.contains(true))
        // The same slot again travels.
        itemMoves = []
        overlay.show(
            items: items,
            activeIndex: 1,
            strip: CGRect(x: 0, y: 0, width: 300, height: 30),
            style: AppBarLook()
        )
        #expect(itemMoves.contains(true))
    }

    /// `contentFrame` is the drawn span in the section's own
    /// coordinates: the run's span moved by the run's origin AND the
    /// viewport's inset, which an overflowing run sets (#1837).
    @Test("The content frame carries the viewport's inset")
    func contentFrameCarriesTheInset() {
        let overlay = AppBarOverlay()
        var look = AppBarLook()
        look.shelf.itemGap = 6
        overlay.show(
            items: (1...12).map { item(UInt32($0)) },
            activeIndex: 0,
            strip: CGRect(x: 0, y: 0, width: 300, height: 30),
            style: look
        )
        #expect(overlay.itemContainer.frame.minX > 0)
        #expect(
            overlay.contentFrame.minX
                == overlay.runContent.minX + overlay.itemRun.frame.minX
                + overlay.itemContainer.frame.minX
        )
    }
}
