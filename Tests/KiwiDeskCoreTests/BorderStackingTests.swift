import AppKit
import Testing

@testable import KiwiDeskCore

/// The ring's panel stacks against a real target in both draw
/// orders (#1917): front lands above it at the target's own level,
/// behind lands below it, and a front glow blooms only outward.
@Suite("Border ring stacking", .serialized)
@MainActor
struct BorderStackingTests {
    private let frame = CGRect(x: -9_000, y: -9_000, width: 60, height: 40)

    @Test(
        "A ring orders against its target in its draw order",
        arguments: [
            (BorderGeometry.Order.above, NSWindow.Level.normal),
            (.above, .floating),
            (.below, .normal),
        ]
    )
    func ringStacksAgainstTarget(
        order: BorderGeometry.Order,
        level: NSWindow.Level
    ) throws {
        let target = makeTarget(level: level)
        defer { target.orderOut(nil) }
        // A window covering the target: a front ring lands between
        // the two, never in front of everything.
        let cover = makeTarget(level: level)
        defer { cover.orderOut(nil) }
        let ring = AppKitBorderOverlay(
            order: order,
            movePanel: { _, _ in false }
        )
        render(ring, order: order, glow: 0)
        defer { ring.hide() }
        _ = onScreenStack(waitingFor: [
            target.windowNumber, cover.windowNumber,
        ])
        ring.order(relativeTo: CGWindowID(target.windowNumber))

        let ringNumber = try #require(ring.panelNumber)
        let stack = onScreenStack(waitingFor: [
            ringNumber, target.windowNumber,
        ])
        let ringIndex = try #require(stack.firstIndex(of: ringNumber))
        let targetIndex = try #require(
            stack.firstIndex(of: target.windowNumber)
        )
        let coverIndex = try #require(
            stack.firstIndex(of: cover.windowNumber)
        )
        if order == .above {
            #expect(coverIndex < ringIndex && ringIndex < targetIndex)
            #expect(ring.panelLevel == level)
        } else {
            #expect(ringIndex > targetIndex)
        }
    }

    /// #1962: a re-stack is read back from WindowServer, never
    /// counted — the SkyLight one was issued and moved nothing.
    @Test("An ordered-in ring re-stacks behind a new target")
    func reorderMovesTheRing() throws {
        let target = makeTarget(level: .normal)
        defer { target.orderOut(nil) }
        let cover = makeTarget(level: .normal)
        defer { cover.orderOut(nil) }
        let ring = AppKitBorderOverlay(
            order: .below,
            movePanel: { _, _ in false }
        )
        render(ring, order: .below, glow: 0)
        defer { ring.hide() }
        _ = onScreenStack(waitingFor: [
            target.windowNumber, cover.windowNumber,
        ])
        ring.order(relativeTo: CGWindowID(target.windowNumber))
        let ringNumber = try #require(ring.panelNumber)
        _ = onScreenStack(waitingFor: [ringNumber])
        ring.order(relativeTo: CGWindowID(cover.windowNumber))
        var stack: [Int] = []
        for _ in 0..<100 {
            stack = onScreenStack(waitingFor: [ringNumber])
            if Self.isDirectlyBehind(ringNumber, cover.windowNumber, stack) {
                break
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        #expect(
            Self.isDirectlyBehind(ringNumber, cover.windowNumber, stack),
            "stack \(stack)"
        )
    }

    private static func isDirectlyBehind(
        _ ring: Int,
        _ window: Int,
        _ stack: [Int]
    ) -> Bool {
        guard let w = stack.firstIndex(of: window),
            let r = stack.firstIndex(of: ring)
        else { return false }
        return r == w + 1
    }

    @Test("A manager's ring reads the level through its seam")
    func managerLevelSeamReachesTheRing() throws {
        let manager = BorderManager()
        manager.movePanel = { _, _ in false }
        manager.setDrawOrder(.front)
        manager.windowLevel = { _ in 5 }
        let overlay = manager.makeOverlay(for: WindowID(7))
        let ring = try #require(overlay.backend as? AppKitBorderOverlay)
        render(ring, order: .above, glow: 0)
        defer { ring.hide() }
        ring.order(relativeTo: 7)
        #expect(ring.panelLevel?.rawValue == 5)
    }

    @Test("A front glow is cut out of its window")
    func frontGlowSparesTheWindow() throws {
        let ring = AppKitBorderOverlay(
            order: .above,
            movePanel: { _, _ in false }
        )
        render(ring, order: .above, glow: 8)
        defer { ring.hide() }
        let masks = ring.glowMaskPaths
        #expect(masks.count == 2)
        for mask in masks {
            let path = try #require(mask)
            let box = path.boundingBox
            #expect(
                !path.contains(
                    CGPoint(x: box.midX, y: box.midY),
                    using: .evenOdd
                )
            )
            #expect(
                path.contains(
                    CGPoint(x: box.minX + 1, y: box.minY + 1),
                    using: .evenOdd
                )
            )
        }
    }

    /// Front-to-back window numbers once `numbers` are all on
    /// screen: WindowServer applies an order after the run loop
    /// turns, so the read pumps it, within a generous bound.
    private func onScreenStack(waitingFor numbers: [Int]) -> [Int] {
        var stack: [Int] = []
        for _ in 0..<100 {
            let info =
                CGWindowListCopyWindowInfo(
                    .optionOnScreenOnly,
                    kCGNullWindowID
                ) as? [[String: Any]] ?? []
            stack = info.compactMap {
                $0[kCGWindowNumber as String] as? Int
            }
            if numbers.allSatisfy(stack.contains) { break }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return stack
    }

    private func render(
        _ ring: AppKitBorderOverlay,
        order: BorderGeometry.Order,
        glow: CGFloat
    ) {
        ring.update(
            geometry: BorderGeometry.compute(
                windowFrame: frame,
                width: 4,
                cornerStyle: .rounded,
                order: order,
                glowBlur: glow
            ),
            colorHex: "#FF0000",
            screen: nil,
            room: nil
        )
    }

    private func makeTarget(level: NSWindow.Level) -> NSPanel {
        let target = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        target.level = level
        target.isReleasedWhenClosed = false
        target.orderFrontRegardless()
        return target
    }
}
