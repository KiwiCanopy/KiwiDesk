import ApplicationServices
import CoreGraphics
import Foundation
import Testing
import os

@testable import KiwiDeskCore

/// A width shrink near a screen's right edge is written from clear
/// of that edge (#2894). The numbers are the three-screen device
/// trace's: a 1728 × 1117 screen, the right stack column ending
/// 16 pt inside its right edge, a spring's tail shrinking 846 → 840
/// while the left edge moves right.
@Suite("A shrink near the right edge is written from clear of it (#2894)")
@MainActor
struct EdgeBandRightEdgeTests {
    private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let upper = CGRect(x: 872, y: 16, width: 840, height: 566)
    private let wide = CGRect(x: 866, y: 16, width: 846, height: 566)

    /// An app answering as macOS did on the device: each axis of a
    /// size write is refused while the window's far edge AND the
    /// asked far edge both lie within the band of that screen edge.
    private final class RefusingApp: Sendable {
        let frame: OSAllocatedUnfairLock<CGRect>
        let screen: CGRect

        init(_ frame: CGRect, screen: CGRect) {
            self.frame = OSAllocatedUnfairLock(initialState: frame)
            self.screen = screen
        }

        func setSize(_ size: CGSize) {
            frame.withLock { now in
                let width =
                    now.maxX > screen.maxX - 20
                    && now.minX + size.width > screen.maxX - 25
                    && size.width < now.width
                let height =
                    now.maxY > screen.maxY - 19
                    && now.minY + size.height > screen.maxY - 25
                    && size.height < now.height
                if !width { now.size.width = size.width }
                if !height { now.size.height = size.height }
            }
        }

        var writer: FrameWriter {
            FrameWriter(
                setFrame: { rect, _ in
                    self.setSize(rect.size)
                    self.frame.withLock { $0.origin = rect.origin }
                    self.setSize(rect.size)
                },
                setPosition: { point, _ in
                    self.frame.withLock { $0.origin = point }
                },
                writeEUI: { _, _ in },
                frame: { _ in self.frame.withLock { $0 } }
            )
        }
    }

    private var element: AXUIElement {
        AXUIElementCreateApplication(getpid())
    }

    @Test("A frame ending near a screen's right edge names that screen")
    func screenNearTheRight() {
        let near = { EdgeBandWrite.screen(for: $0, among: [self.screen]) }
        #expect(near(upper) == screen)
        #expect(near(upper.offsetBy(dx: -200, dy: 0)) == nil)
        let below = screen.offsetBy(dx: 0, dy: screen.height)
        #expect(EdgeBandWrite.screen(for: upper, among: [below]) == nil)
    }

    @Test("A width shrink moves the window left and keeps its top")
    func shrinkMovesLeft() {
        let origin = EdgeBandWrite.liftedOrigin(
            target: upper,
            current: wide,
            screen: screen
        )
        #expect(origin == CGPoint(x: 1728 - EdgeBandWrite.band - 846, y: 16))
    }

    @Test("The refusing app keeps the old width without the move")
    func unmovedWriteIsRefused() {
        let app = RefusingApp(wide, screen: screen)
        EdgeBandWrite.write(
            upper,
            element,
            nearEdgeOf: nil,
            writer: app.writer
        )
        #expect(app.frame.withLock { $0.width } == 846)
    }

    /// Each applier door with a size, as `EdgeBandWriteTests`.
    enum Door: String, CaseIterable { case animated, instant, held }

    private func land(
        _ target: CGRect,
        from current: CGRect,
        through door: Door
    ) async throws -> CGRect {
        let app = RefusingApp(current, screen: screen)
        let applier = FrameApplier()
        let element = element
        applier.elementProvider = { _ in element }
        applier.writer = app.writer
        applier.screenFrames = { [screen] in [screen] }
        let id = WindowID(1)
        switch door {
        case .animated:
            applier.apply(id, target, setSize: true)
        case .instant:
            applier.applyInstant(id, target, setSize: true)
        case .held:
            applier.holdWrites([id], until: .now() + 0.05)
            applier.applyInstant(id, target, setSize: true)
        }
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500 where app.frame.withLock({ $0 }) == current {
            try await Task.sleep(for: .milliseconds(10))
        }
        return app.frame.withLock { $0 }
    }

    @Test(
        "Every applier write path lands a right-edge shrink",
        arguments: Door.allCases
    )
    func rightEdgeShrinkLands(door: Door) async throws {
        #expect(try await land(upper, from: wide, through: door) == upper)
    }

    /// The lower right window of the device trace: its bottom and
    /// its right side both end in a band.
    @Test(
        "A corner shrink lands on both axes",
        arguments: Door.allCases
    )
    func cornerShrinkLands(door: Door) async throws {
        let slot = CGRect(x: 872, y: 606.5, width: 840, height: 494.5)
        let start = CGRect(x: 866, y: 602, width: 846, height: 499)
        #expect(try await land(slot, from: start, through: door) == slot)
    }
}
