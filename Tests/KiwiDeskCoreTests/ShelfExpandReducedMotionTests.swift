import AppKit
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// The shelf's expand plays under Reduce Motion (owner ruling,
/// 2026-10-21): every frame and fade written inside its group
/// travels, while a bar write outside it — an item run re-flowing —
/// keeps the gate. Owner device report, same day: with the gate
/// still on the writes, the expand snapped. Main-actor spend: two
/// unwindowed views.
@Suite("Shelf expand under Reduce Motion", .serialized)
@MainActor
struct ShelfExpandReducedMotionTests {
    private func view() -> NSView {
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        view.wantsLayer = true
        return view
    }

    private func moving(_ view: NSView) -> Bool {
        view.layer?.animationKeys()?.isEmpty == false
    }

    @Test("Inside the expand a frame and a fade travel")
    func expandTravels() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let glide = BarMotion.shelfGlide
        BarMotion.shelfGlide = 0.75
        defer { BarMotion.shelfGlide = glide }
        let framed = view()
        let faded = view()
        BarMotion.runPlateGlide {
            BarMotion.setFrame(
                framed,
                to: CGRect(x: 0, y: 0, width: 40, height: 10),
                animated: true
            )
            BarMotion.setAlpha(faded, to: 0, animated: true)
        }
        #expect(moving(framed))
        #expect(moving(faded))
        #expect(!BarMotion.inExpand)
    }

    @Test("Outside the expand Reduce Motion still lands the write")
    func itemRunStaysGated() {
        BarMotion.reducedOverride = true
        defer { BarMotion.reducedOverride = nil }
        let framed = view()
        BarMotion.runLayout {
            BarMotion.setFrame(
                framed,
                to: CGRect(x: 0, y: 0, width: 40, height: 10),
                animated: true
            )
        }
        #expect(!moving(framed))
        #expect(framed.frame.width == 40)
    }
}
