import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pocket handle's look and its Reduce Motion countdown (#3368),
/// split from `PocketApproachTests` at the §2.1 ceiling: the tab is
/// constant and the kiwis carry the empty fade; under Reduce Motion
/// the tab counts down with the bars' fill, under Off nothing shows.
extension PocketApproachTests {
    @Test("Reduce Motion counts down on the tab; Off shows nothing")
    func reducedFillsTheTab() throws {
        defer { BarMotion.reducedOverride = nil }
        // Reduce Motion, then KiwiDesk's Off (no reveal length).
        for off in [false, true] {
            let rig = try rig()
            BarMotion.reducedOverride = true
            if off { BarMotion.revealLength = 0 }
            defer { pinRevealLength() }
            let rest = try #require(rig.spec)
            rig.move(to: try nearTab(try #require(rig.target)))
            let fill = try #require(rig.core.shelves.reveal.fills[rig.key])
            // The pocket holds still in its resting room.
            let still = try #require(rig.spec)
            #expect(still.rise == nil)
            #expect(still.frame == rest.frame)
            // The countdown is the tab's, from the one approach clock.
            #expect(still.tabFill == fill)
            let view = try #require(
                rig.core.pocketPlate.view(on: rig.display)
            )
            view.layoutSubtreeIfNeeded()
            let tab = view.handle
            #expect(tab.fill == fill)
            #expect(tab.fillLayer.isHidden == off, "off: \(off)")
            #expect(
                (tab.fillLayer.animation(forKey: BarMotion.handleFillKey)
                    != nil) == !off
            )
            // The fill runs inside the tab's core capsule.
            #expect(tab.fillClip.frame == tab.tabCoreFrame())
            #expect(tab.fillClip.masksToBounds)
            // It stands at the dwell's end, and the fill clears.
            rig.timers.fireAll()
            rig.pass()
            let risen = try #require(rig.spec)
            #expect(risen.risen)
            #expect(risen.tabFill == nil)
        }
    }

    @Test("an empty pocket fades its kiwis, the tab stays")
    func kiwisFade() throws {
        let rig = try rig()
        defer { BarMotion.reducedOverride = nil }
        let rest = try #require(rig.spec)
        #expect(rest.faded)
        let view = try #require(rig.core.pocketPlate.view(on: rig.display))
        #expect(view.window?.alphaValue == 1)
        #expect(view.handle.faded)
        #expect(view.pocket.alphaValue == PocketPlateOverlay.fadedAlpha)
        // A hover shows it full.
        rig.core.pocketHovered(rest.display, true)
        #expect(!view.handle.faded)
        #expect(view.pocket.alphaValue == 1)
    }

    @Test("the whole mark keeps its empty fade")
    func wholeMarkFades() throws {
        let rig = try rig(visibility: "always")
        defer { BarMotion.reducedOverride = nil }
        let rest = try #require(rig.spec)
        #expect(rest.whole)
        let view = try #require(rig.core.pocketPlate.view(on: rig.display))
        #expect(view.window?.alphaValue == PocketPlateOverlay.fadedAlpha)
        #expect(!view.handle.faded)
        // The whole mark files no approach.
        #expect(rig.target == nil)
    }

    @Test("the hovered tab takes the fill strength, the kiwis stay")
    func tabStrength() {
        let light = NSAppearance(named: .aqua)
        var rest: CGFloat = 0
        var full: CGFloat = 0
        light?.performAsCurrentDrawingAppearance {
            rest =
                PocketHandleView.tabCore(hex: "", hovered: false)
                .alphaComponent
            full =
                PocketHandleView.tabCore(hex: "", hovered: true)
                .alphaComponent
        }
        #expect(abs(rest - ShelfHandleSpec.restStrength) < 0.001)
        #expect(abs(full - ShelfHandleSpec.fillStrength) < 0.001)
    }
}
