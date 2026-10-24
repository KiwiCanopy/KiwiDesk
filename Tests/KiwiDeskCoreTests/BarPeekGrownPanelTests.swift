import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The panel a bar item's list grows in (#2571 ▸ Ruling): it takes
/// the keyboard as the overflow mark's does, a list of either kind
/// replaces the other whole, and a bar list fades as it retracts.
@Suite("Bar list grown panel", .serialized)
@MainActor
struct BarPeekGrownPanelTests {
    init() {
        LiquidGlassGate.override = { false }
    }

    /// An overflow mark's pill, as far as the peek asks of one.
    final class Pill: NSView, BarPeekMorphAnchor {
        var morphed = false
        var morphRoom: CGRect {
            CGRect(x: 0, y: 0, width: 1920, height: 1200)
        }
        var morphText: String { "+2" }
        func setMorphed(_ morphed: Bool, pointer: CGPoint) {
            self.morphed = morphed
        }
    }

    private func clickList(_ rig: BarPeekRig) {
        rig.peek.clicked(
            rig.first,
            source: .glyph([WindowID(1), WindowID(2)]),
            space: SpaceID("1"),
            edge: .top,
            clickCount: 1
        )
    }

    private func clickPill(_ rig: BarPeekRig, _ pill: Pill) {
        rig.peek.clicked(
            pill,
            source: .run([WindowID(7), WindowID(8)]),
            space: nil,
            edge: .top,
            clickCount: 1
        )
    }

    @Test("A bar list's panel takes the keyboard, its header hidden")
    func grownListTakesKeys() throws {
        let rig = BarPeekRig()
        defer { rig.close() }
        clickList(rig)
        let panel = try #require(rig.peek.panel.panel)
        #expect(panel.takesKey)
        #expect(panel.canBecomeKey)
        #expect(rig.peek.panel.morph?.growth == .outOfItem)
        #expect(rig.peek.panel.morph?.item === rig.first)
        #expect(rig.peek.panel.header.isHidden)
        rig.peek.dismiss()
        rig.step()
        #expect(!panel.takesKey, "a closed list gives the keyboard back")
    }

    /// A list of one kind showing when the other opens ends at once,
    /// so the new one grows from its own start: the pill hides as its
    /// list opens and comes back as a bar list takes its place.
    @Test("A pill list and a bar list replace each other whole")
    func kindsReplaceEachOther() {
        let rig = BarPeekRig()
        defer { rig.close() }
        let pill = Pill(frame: CGRect(x: 100, y: 10, width: 24, height: 18))
        rig.item.addSubview(pill)
        clickList(rig)
        clickPill(rig, pill)
        #expect(rig.peek.panel.morph?.growth == .fromPill)
        #expect(pill.morphed, "the pill hides as its list opens")
        #expect(!rig.peek.panel.header.isHidden)
        clickList(rig)
        #expect(rig.peek.panel.morph?.growth == .outOfItem)
        #expect(!pill.morphed, "the pill comes back")
        #expect(rig.peek.panel.header.isHidden)
    }

    /// A bar list fades over its retract, so no plate rests while
    /// the spring settles; the overflow mark's shrinks into its pill
    /// whole (device, 2026-10-24).
    @Test("A bar list's close fades its stage at the call site")
    func closeFadesAtTheCallSite() throws {
        let was = (BarMotion.peekMotion, BarMotion.reducedOverride)
        defer {
            BarMotion.peekMotion = was.0
            BarMotion.reducedOverride = was.1
        }
        BarMotion.peekMotion = true
        BarMotion.reducedOverride = false
        let rig = BarPeekRig()
        defer { rig.close() }
        clickList(rig)
        let stage = try #require(rig.peek.panel.stage.layer)
        rig.peek.dismiss()
        #expect(
            stage.animationKeys()?.contains(BarMotion.morphFadeKey) == true
        )
        let pill = Pill(frame: CGRect(x: 100, y: 10, width: 24, height: 18))
        rig.item.addSubview(pill)
        rig.step()
        clickPill(rig, pill)
        rig.peek.dismiss()
        #expect(
            stage.animationKeys()?.contains(BarMotion.morphFadeKey) != true
        )
    }
}
