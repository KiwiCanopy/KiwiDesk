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
