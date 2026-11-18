import AppKit
import Foundation
import QuartzCore
import Testing

@testable import KiwiDeskCore

/// A pocket that holds something (#3446): its kiwis alone look out
/// further past the tab, which stays flush, and the resting frame
/// and the rise's travel read the same depth the view draws, so a
/// put-in or take-out sinks to where the kiwis then stand.
@Suite(
    "Pocket handle held look-out (#3446)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct PocketHeldLookOutTests {
    /// The kiwis' topmost inked row and the tab's core alpha, in
    /// points from the top, of a bottom-edge handle `height` deep
    /// drawn at 2x.
    private func draw(holds: Bool, height: CGFloat) throws -> (
        top: CGFloat, tab: CGFloat
    ) {
        let size = CGSize(width: 40, height: height)
        let view = PocketHandleView(frame: CGRect(origin: .zero, size: size))
        view.appearance = NSAppearance(named: .darkAqua)
        view.holds = holds
        view.wear(
            KiwiShelf(),
            markHex: "#FF0000",
            edge: .bottom,
            kiwisOut: false
        )
        let scale: CGFloat = 2
        let rep = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width * scale),
                pixelsHigh: Int(size.height * scale),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        // Above the tab only the kiwis draw, in their own green.
        let depth = PocketHandleView.tabDepth(of: KiwiShelf())
        let tabTop = Int((height - depth) * scale)
        var top: Int?
        rows: for y in 0..<tabTop {
            for x in 0..<rep.pixelsWide {
                guard let c = rep.colorAt(x: x, y: y) else { continue }
                if c.alphaComponent > 0.5 {
                    top = y
                    break rows
                }
            }
        }
        let found = try #require(top, "no kiwis drawn")
        let tab =
            rep.colorAt(
                x: rep.pixelsWide / 2,
                y: Int((height - 1.5) * scale)
            )?.alphaComponent ?? 0
        return (CGFloat(found) / scale, tab)
    }

    @Test("the kiwis look out 3 pt further while it holds, tab flush")
    func kiwisLookFurther() throws {
        let height: CGFloat = 20
        let empty = try draw(holds: false, height: height)
        let held = try draw(holds: true, height: height)
        let further =
            PocketHandleView.lookOut(holds: true)
            - PocketHandleView.lookOut(holds: false)
        #expect(further > 0)
        #expect(abs((empty.top - held.top) - further) < 0.75)
        // The tab stays flush on the edge, drawn in both.
        #expect(empty.tab > 0.3, "empty tab \(empty.tab)")
        #expect(held.tab > 0.3, "held tab \(held.tab)")
    }

    @Test("the rise starts where the kiwis look out, held or not")
    func travelReadsTheHeldDepth() {
        let further =
            PocketHandleView.lookOut(holds: true)
            - PocketHandleView.lookOut(holds: false)
        let tab = PocketHandleView.tabDepth(of: KiwiShelf())
        let travel = {
            BarMotion.pocketRiseTravel(holds: $0, tabDepth: tab)
        }
        #expect(abs((travel(false) - travel(true)) - further) < 0.001)
        let start = {
            BarMotion.pocketRiseStart(
                edge: .bottom,
                side: 40,
                travel: travel($0)
            )
        }
        #expect(abs((start(false).m42 - start(true).m42) - further) < 0.001)
    }

    @Test("the resting handle deepens while the pocket holds a window")
    func frameReadsWhatItHolds() throws {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-held-\(UUID().uuidString)")
        )
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.kiwiDisplayID)
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.upsertDisplay(
            Display(id: id, name: "Main", frame: screen.frame)
        )
        core.state.workspaces.assign(space, to: id)
        core.tiler.settings.spaceBarStyle.visibility = .hidden
        core.execute(
            "kiwishelf.set_pocket_visibility",
            args: [.string("auto")]
        )
        let edge = core.tiler.settings.kiwishelf.pocketEdge
        let shelf = core.tiler.settings.kiwishelf
        let depth = { (frame: CGRect) in
            edge.isHorizontal ? frame.height : frame.width
        }
        let empty = try #require(core.pocketHandleFrame(on: id, risen: false))
        let window = WindowID(900_301)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 900_301, appName: "App")
            )
        )
        core.state.workspaces.add(window, to: space)
        _ = core.state.markPocketWindow(window)
        core.state.pocketWindow(window)
        #expect(!core.pocketPlateWindows.isEmpty)
        let held = try #require(core.pocketHandleFrame(on: id, risen: false))
        #expect(
            abs(
                (depth(held) - depth(empty))
                    - (PocketHandleView.restDepth(holds: true, of: shelf)
                        - PocketHandleView.restDepth(
                            holds: false,
                            of: shelf
                        ))
            ) < 0.001
        )
        #expect(depth(held) > depth(empty))
    }

    @Test("a held pocket's sink lands where the held kiwis stand")
    func sinkTakesTheHeldTravel() throws {
        let rig = try PocketApproachTests().rig()
        defer { BarMotion.reducedOverride = nil }
        rig.core.pocketPlate.afterLeave = { _, _ in }
        let window = WindowID(900_302)
        let core = rig.core
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 900_302, appName: "App")
            )
        )
        let space = try #require(core.state.workspaces.activeSpace)
        core.state.workspaces.add(window, to: space)
        _ = core.state.markPocketWindow(window)
        core.state.pocketWindow(window)
        rig.pass()
        let rest = try #require(rig.spec)
        #expect(rest.holds)
        let view = try #require(core.pocketPlate.view(on: rig.display))
        #expect(view.handle.holds)
        rig.move(
            to: try PocketApproachTests().nearTab(try #require(rig.target))
        )
        try PocketRiseSequenceTests.seed(view, rig, done: 0.5)
        rig.move(to: CGPoint(x: -10_000, y: -10_000))
        let sink = try #require(
            view.pocket.layer?.animation(forKey: BarMotion.pocketRiseKey)
                as? CABasicAnimation
        )
        let to = try #require(
            (sink.toValue as? NSValue)?.caTransform3DValue
        )
        let edge = try #require(rest.handle)
        let landing = { (holds: Bool) in
            BarMotion.pocketRiseStart(
                edge: edge,
                side: rest.risenSide,
                travel: BarMotion.pocketRiseTravel(
                    holds: holds,
                    tabDepth: PocketHandleView.tabDepth(of: rest.shelf)
                )
            )
        }
        #expect(CATransform3DEqualToTransform(to, landing(true)))
        #expect(!CATransform3DEqualToTransform(to, landing(false)))
    }
}
