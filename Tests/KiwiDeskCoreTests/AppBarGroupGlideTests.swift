import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A group's members slide into its item as it collapses and out
/// of it as it expands (#1831): the item views are keyed by their
/// window, so the mapping — which view stays, which folds into
/// which item, which starts on which slot — is what these read.
/// The motion itself is `BarMotion`'s, gated on Reduce Motion.
@Suite("App Bar group glide", .serialized)
@MainActor
struct AppBarGroupGlideTests {
    private func item(_ id: UInt32, members: [UInt32]? = nil)
        -> AppBarOverlay.Item
    {
        AppBarOverlay.Item(
            id: WindowID(id),
            name: "App",
            text: "App",
            icon: nil,
            count: members?.count ?? 1,
            members: members?.map(WindowID.init)
        )
    }

    private func show(
        _ overlay: AppBarOverlay,
        _ items: [AppBarOverlay.Item]
    ) {
        overlay.show(
            items: items,
            activeIndex: nil,
            strip: CGRect(x: 0, y: 0, width: 900, height: 30),
            style: AppBarLook()
        )
    }

    @Test("A collapsing group keeps its view and folds the members in")
    func collapseFoldsMembers() {
        let overlay = AppBarOverlay()
        show(overlay, [item(1), item(2), item(3), item(9)])
        let first = overlay.itemViews[0]
        let second = overlay.itemViews[1]
        let third = overlay.itemViews[2]
        let other = overlay.itemViews[3]
        let glide = overlay.syncItemViews(
            to: [item(1, members: [1, 2, 3]), item(9)]
        )
        // The group's view and the neighbour's are the same objects,
        // so their frame writes glide rather than swap content.
        #expect(overlay.itemViews[0] === first)
        #expect(overlay.itemViews[1] === other)
        #expect(
            Set(glide.departures.map { ObjectIdentifier($0.view) })
                == [ObjectIdentifier(second), ObjectIdentifier(third)]
        )
        #expect(glide.departures.allSatisfy { $0.into == WindowID(1) })
        #expect(glide.arrivals.isEmpty)
    }

    @Test("An expanding group releases its members from its slot")
    func expandReleasesMembers() {
        let overlay = AppBarOverlay()
        show(overlay, [item(1, members: [1, 2, 3]), item(9)])
        let group = overlay.itemViews[0]
        let slot = group.frame
        let glide = overlay.syncItemViews(
            to: [item(1), item(2), item(3), item(9)]
        )
        #expect(overlay.itemViews[0] === group)
        #expect(glide.departures.isEmpty)
        #expect(glide.arrivals.count == 2)
        #expect(glide.arrivals.allSatisfy { $0.from == slot })
        #expect(
            glide.arrivals.map { ObjectIdentifier($0.view) }
                == overlay.itemViews[1...2].map(ObjectIdentifier.init)
        )
    }

    @Test("A window that leaves the bar goes at once")
    func closedWindowLeavesAtOnce() {
        let overlay = AppBarOverlay()
        show(overlay, [item(1), item(2)])
        let closed = overlay.itemViews[1]
        let glide = overlay.syncItemViews(to: [item(1)])
        #expect(glide.departures.isEmpty)
        #expect(closed.superview == nil)
    }

    @Test("An arrival stands on its group's slot, transparent")
    func arrivalStandsOnSlot() {
        let overlay = AppBarOverlay()
        show(overlay, [item(1, members: [1, 2])])
        let slot = overlay.itemViews[0].frame
        let glide = overlay.syncItemViews(to: [item(1), item(2)])
        overlay.standArrivals(glide.arrivals)
        let arrival = overlay.itemViews[1]
        #expect(arrival.frame == slot)
        #expect(arrival.alphaValue == 0)
        #expect(overlay.itemViews[0].alphaValue == 1)
    }

    @Test("An alpha write fades only where motion is allowed")
    func fadeGate() {
        #expect(BarMotion.fades(true, reduceMotion: false))
        #expect(!BarMotion.fades(true, reduceMotion: true))
        #expect(!BarMotion.fades(false, reduceMotion: false))
    }
}
