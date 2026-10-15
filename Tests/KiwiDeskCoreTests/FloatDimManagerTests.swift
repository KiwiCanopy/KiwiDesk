import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiVision's per-float veils (#2103 ruling 3) on inert panels:
/// a wanted float's veil covers its ring's reach and orders above
/// its anchor; a float that leaves the set goes dormant, still
/// ordered in; a gone float's veil goes; the float's reorder event
/// puts the veil back above its chrome.
@Suite("Float veils")
@MainActor
struct FloatDimManagerTests {
    private let f1 = WindowID(11)
    private let frame = CGRect(x: 100, y: 100, width: 400, height: 300)

    private func make() -> (FloatDimManager, () -> [InertFloatDim]) {
        let manager = FloatDimManager()
        var made: [InertFloatDim] = []
        manager.panelFactory = {
            let panel = InertFloatDim()
            made.append(panel)
            return panel
        }
        return (manager, { made })
    }

    private func request(
        _ floats: [FloatDimManager.Float],
        on: Bool = true
    ) -> FloatDimManager.Request {
        FloatDimManager.Request(
            floats: floats,
            on: on,
            dim: 0.6,
            blur: true,
            tracked: true
        )
    }

    private func float(
        anchor: CGWindowID = 900,
        spans: Bool = false
    ) -> FloatDimManager.Float {
        FloatDimManager.Float(
            id: f1,
            frame: frame,
            outset: 5,
            cornerRadius: 15,
            anchor: anchor,
            spans: spans
        )
    }

    @Test("a wanted float's veil covers its ring and sits above its mark")
    func veilCoversTheFloat() throws {
        let (manager, made) = make()
        manager.sync(request([float()]), alive: [f1], reassert: false)
        let panel = try #require(made().first)
        #expect(panel.isShown)
        #expect(panel.frame == frame.insetBy(dx: -5, dy: -5))
        #expect(panel.cornerRadius == 15)
        #expect(panel.dim == 0.6)
        #expect(panel.blur == true)
        #expect(panel.orders == [900])
        #expect(manager.shown == [f1])
    }

    @Test("a steady sync orders nothing; a new anchor orders again")
    func ordersOnlyWhenOwed() throws {
        let (manager, made) = make()
        manager.sync(request([float()]), alive: [f1], reassert: false)
        manager.sync(request([float()]), alive: [f1], reassert: false)
        let panel = try #require(made().first)
        #expect(panel.orders == [900])
        manager.sync(
            request([float(anchor: 901)]),
            alive: [f1],
            reassert: false
        )
        #expect(panel.orders == [900, 901])
    }

    @Test("a float that leaves the set goes dormant, still ordered in")
    func leftFloatGoesDormant() throws {
        let (manager, made) = make()
        manager.sync(request([float()]), alive: [f1], reassert: false)
        manager.sync(request([]), alive: [f1], reassert: false)
        let panel = try #require(made().first)
        #expect(!panel.isShown)
        #expect(panel.orderedOut == 0)
        #expect(manager.dormant == [f1])
        // Coming back it orders again: the stack moved meanwhile.
        manager.sync(request([float()]), alive: [f1], reassert: false)
        #expect(panel.isShown)
        #expect(panel.orders == [900, 900])
        #expect(made().count == 1)
    }

    @Test("a gone float's veil goes")
    func goneFloatDrops() throws {
        let (manager, made) = make()
        manager.sync(request([float()]), alive: [f1], reassert: false)
        manager.sync(request([]), alive: [], reassert: false)
        let panel = try #require(made().first)
        #expect(panel.orderedOut == 1)
        #expect(manager.dormant.isEmpty && manager.shown.isEmpty)
    }

    @Test("the float's reorder event puts the veil back above its anchor")
    func restackReorders() throws {
        let (manager, made) = make()
        manager.sync(request([float()]), alive: [f1], reassert: false)
        manager.restack(f1)
        manager.hideWindow(f1)
        let panel = try #require(made().first)
        #expect(panel.orders == [900, 900])
        #expect(panel.orderedOut == 1)
    }

    @Test("a float that stops being carried is ordered off every Desktop")
    func spanChangeRehomes() throws {
        let (manager, made) = make()
        manager.sync(
            request([float(spans: true)]),
            alive: [f1],
            reassert: false
        )
        let panel = try #require(made().first)
        #expect(panel.spans)
        manager.sync(request([float()]), alive: [f1], reassert: false)
        #expect(!panel.spans)
        #expect(panel.orderedOut == 1)
        #expect(panel.orders == [900, 900])
    }

    @Test("the veil follows a reported frame only while it shows")
    func followMovesTheVeil() throws {
        let (manager, made) = make()
        let moved = frame.offsetBy(dx: 40, dy: 0)
        manager.follow(f1, windowFrame: moved, source: .axEcho, pin: nil)
        #expect(made().isEmpty)
        manager.sync(request([float()]), alive: [f1], reassert: false)
        manager.follow(f1, windowFrame: moved, source: .axEcho, pin: nil)
        let panel = try #require(made().first)
        #expect(panel.frame == moved.insetBy(dx: -5, dy: -5))
    }

    @Test("the veil anchors on the chrome ordered earliest")
    func anchorIsTheTopmostChrome() {
        #expect(FloatDimManager.anchor(chrome: [nil, nil], float: 7) == 7)
        #expect(
            FloatDimManager.anchor(chrome: [(70, 3), nil], float: 7) == 70
        )
        // A ring ordered before the mark sits above it.
        #expect(
            FloatDimManager.anchor(chrome: [(70, 3), (80, 5)], float: 7)
                == 70
        )
        #expect(
            FloatDimManager.anchor(chrome: [(70, 6), (80, 5)], float: 7)
                == 80
        )
    }

    @Test("off, every veil fades and goes for good")
    func offRetiresEveryVeil() throws {
        let (manager, made) = make()
        manager.sync(request([float()]), alive: [f1], reassert: false)
        manager.sync(request([], on: false), alive: [f1], reassert: false)
        let panel = try #require(made().first)
        #expect(!panel.isShown)
        #expect(panel.orderedOut == 1)
        #expect(manager.shown.isEmpty && manager.dormant.isEmpty)
    }
}
