import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Space switch DISSOLVES the App Bar's row (#1838): the old
/// items stay where they stand and fade out while the new fade in
/// at their slots — keyed on the Space the manager hands `show`,
/// never on a close within a Space nor on the first show after a
/// hide — and on a boxed glass run the boxes move by geometry.
@Suite("App Bar dissolve", .serialized)
@MainActor
struct AppBarDissolveTests {
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

    /// A Space switch dissolves (#1838): the old row's views stay
    /// where they stand, fading, into no item, and every new view
    /// fades in at its own slot rather than from a group's.
    @Test("A dissolve keeps the old row fading and fades the new in")
    func dissolveFadesRows() {
        let overlay = AppBarOverlay()
        show(overlay, [item(1), item(2)])
        let old = overlay.itemViews
        let glide = overlay.syncItemViews(
            to: [item(7), item(8), item(9)],
            glass: false,
            dissolving: true
        )
        #expect(glide.departures.count == 2)
        #expect(glide.departures.allSatisfy { $0.into == nil })
        #expect(old.allSatisfy { $0.superview === overlay.itemRun })
        #expect(glide.arrivals.count == 3)
        #expect(glide.arrivals.allSatisfy { $0.from == .zero })
        // A dissolve arrival slides under no glass, so it is not
        // held bare until it lands.
        #expect(overlay.glidingIn.isEmpty)
        overlay.standArrivals(glide.arrivals)
        #expect(overlay.itemViews.allSatisfy { $0.alphaValue == 0 })
    }

    /// The dissolve is a SWITCH's: a show for another Space, never
    /// a close within one, and never the first show after a hide.
    @Test("Only a show for another Space dissolves")
    func dissolveIsASwitch() async throws {
        let before = BarMotion.shelfGlide
        defer { BarMotion.shelfGlide = before }
        BarMotion.shelfGlide = 0.05
        let overlay = AppBarOverlay()
        let strip = CGRect(x: 0, y: 0, width: 900, height: 30)
        overlay.show(
            items: [item(1), item(2)],
            activeIndex: nil,
            strip: strip,
            style: AppBarLook(),
            space: SpaceID("1")
        )
        let old = overlay.itemViews
        overlay.show(
            items: [item(7)],
            activeIndex: nil,
            strip: strip,
            style: AppBarLook(),
            space: SpaceID("2")
        )
        // Still in the run, fading, until the glide lands.
        #expect(old.allSatisfy { $0.superview === overlay.itemRun })
        for _ in 0..<150 where old.contains(where: { $0.superview != nil }) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(old.allSatisfy { $0.superview == nil })
        // A close within the Space goes at once.
        overlay.show(
            items: [item(7), item(8)],
            activeIndex: nil,
            strip: strip,
            style: AppBarLook(),
            space: SpaceID("2")
        )
        let closing = overlay.itemViews[1]
        overlay.show(
            items: [item(7)],
            activeIndex: nil,
            strip: strip,
            style: AppBarLook(),
            space: SpaceID("2")
        )
        #expect(closing.superview == nil)
        // A reappearance after a hide discards, never dissolves.
        let stale = overlay.itemViews[0]
        overlay.hide()
        overlay.show(
            items: [item(3)],
            activeIndex: nil,
            strip: strip,
            style: AppBarLook(),
            space: SpaceID("3")
        )
        #expect(stale.superview == nil)
    }

    /// On a boxed glass run the boxes CUT and only content dissolves
    /// (#1838): a leaving view is taken out of its glass, which goes
    /// at once, and fades bare; an arriving one takes a fresh glass
    /// at once and fades in inside it. A glass takes no alpha — at
    /// partial opacity it shows the tint behind it bare — and no
    /// geometry — its content re-lays every frame.
    @Test("A boxed glass dissolve cuts the boxes and fades the content")
    func glassDissolveCutsBoxes() async throws {
        guard #available(macOS 26, *) else { return }
        let gate = LiquidGlassGate.override
        defer { LiquidGlassGate.override = gate }
        LiquidGlassGate.override = { false }
        let before = BarMotion.shelfGlide
        defer { BarMotion.shelfGlide = before }
        BarMotion.shelfGlide = 0.05
        var style = AppBarLook()
        style.liquidGlass = true
        style.backgroundStyle = .boxed
        let overlay = AppBarOverlay()
        let strip = CGRect(x: 0, y: 0, width: 900, height: 30)
        overlay.show(
            items: [item(1), item(2)],
            activeIndex: nil,
            strip: strip,
            style: style,
            space: SpaceID("1")
        )
        let oldGlasses = overlay.boxGlasses
        let oldViews = overlay.itemViews
        overlay.show(
            items: [item(7)],
            activeIndex: nil,
            strip: strip,
            style: style,
            space: SpaceID("2")
        )
        // Leaving boxes go at once; their views fade bare in the run.
        #expect(oldGlasses.allSatisfy { $0.superview == nil })
        #expect(oldViews.allSatisfy { $0.superview === overlay.itemRun })
        // The arriving box is a fresh one, at full opacity, hosting
        // its view.
        #expect(overlay.boxGlasses.count == 1)
        let arriving = try #require(overlay.boxGlasses.first)
        #expect(!oldGlasses.contains { $0 === arriving })
        #expect(arriving.alphaValue == 1)
        #expect(arriving.frame.width > 0)
        #expect(GlassPlate.holds(arriving, overlay.itemViews[0]))
        for _ in 0..<150
        where oldViews.contains(where: { $0.superview != nil }) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(oldViews.allSatisfy { $0.superview == nil })
    }
}
