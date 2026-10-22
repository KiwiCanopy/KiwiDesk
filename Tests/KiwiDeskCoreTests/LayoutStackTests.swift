import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)
private let w4 = WindowID(4)
private let w5 = WindowID(5)
private let w6 = WindowID(6)

private func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 1920, height: 1080),
    gaps: Gaps = .uniform(10),
    focused: WindowID? = nil
) -> LayoutContext {
    LayoutContext(bounds: bounds, gaps: gaps, focused: focused)
}

@Suite("Stack layout")
struct StackLayoutTests {
    let layout = StackLayout()

    @Test("Master alone gets the full width")
    func masterOnly() throws {
        let context = makeContext()
        let frames = layout.calculateGeometry(
            for: [w1],
            in: context
        )
        #expect(frames[w1] == context.usable)
    }

    @Test("Master zone takes masterRatio of the width")
    func masterAndStack() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2],
            in: makeContext()
        )
        let master = try #require(frames[w1])
        let stack = try #require(frames[w2])
        #expect(abs(master.width - 1890 * 0.6) < 0.01)
        #expect(abs(stack.minX - master.maxX - 10) < 0.01)
        #expect(master.height == 1060)
        #expect(stack.height == 1060)
    }

    @Test("Stack zone distributes windows evenly")
    func stackDistribution() throws {
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4],
            in: makeContext()
        )
        let s1 = try #require(frames[w2])
        let s2 = try #require(frames[w3])
        let s3 = try #require(frames[w4])
        let expected = (1060.0 - 20) / 3
        #expect(abs(s1.height - expected) < 0.01)
        #expect(abs(s2.minY - s1.maxY - 10) < 0.01)
        #expect(abs(s3.minY - s2.maxY - 10) < 0.01)
    }

    @Test("masterCount 2: masters sit side by side by default")
    func multiMaster() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let m1 = try #require(frames[w1])
        let m2 = try #require(frames[w2])
        #expect(m1.minY == m2.minY)
        #expect(m2.minX > m1.minX)
        #expect(frames[w3]?.minX ?? 0 > m2.maxX)
    }

    @Test("vertical master orientation stacks masters in a column")
    func multiMasterVertical() throws {
        var context = makeContext()
        context.stack.masterCount = 2
        context.stack.masterOrientation = .vertical
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3],
            in: context
        )
        let m1 = try #require(frames[w1])
        let m2 = try #require(frames[w2])
        #expect(m1.minX == m2.minX)
        #expect(m2.minY > m1.minY)
        #expect(frames[w3]?.minX ?? 0 > m1.maxX)
    }

    @MainActor
    @Test("Column overflow shows what fits, parks the rest")
    func partialOverflow() throws {
        // Usable 780pt tall; two stack windows fit at 300pt, so
        // the other two wait parked (#2235).
        let frames = layout.calculateGeometry(
            for: [w1, w2, w3, w4, w5],
            in: makeContext(
                bounds: CGRect(
                    x: 0,
                    y: 0,
                    width: 1920,
                    height: 800
                )
            )
        )
        let top = try #require(frames[w2])
        let edge = try #require(frames[w3])
        // The two shown share the zone: (780 - 10) / 2 each.
        #expect(abs(top.minY - 10) < 0.01)
        #expect(abs(top.height - 385) < 0.01)
        #expect(abs(edge.minY - top.maxY - 10) < 0.01)
        #expect(abs(edge.maxY - 790) < 0.01)
        // Hidden windows rest parked at the hide corner (#2235).
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 800)
        for hidden in [w4, w5] {
            let frame = try #require(frames[hidden])
            #expect(TilingEngine.looksStashed(frame, in: screen))
        }
    }

    @Test("StackParams decodes profiles missing new fields")
    func decodeOldProfile() throws {
        // A profile saved before the orientation fields existed.
        let old = #"{"master_count":2,"master_ratio":0.7}"#
        let params = try JSONDecoder().decode(
            StackParams.self,
            from: Data(old.utf8)
        )
        #expect(params.masterCount == 2)
        #expect(params.masterRatio == 0.7)
        #expect(params.stackPosition == .right)
    }

    @Test("Promote swaps with the last master window")
    func promote() throws {
        var space = Space(id: "s", windows: [w1, w2, w3])
        space.promote(w3, masterCount: 1)
        #expect(space.windows == [w3, w2, w1])
        // Already master: no-op.
        space.promote(w3, masterCount: 1)
        #expect(space.windows == [w3, w2, w1])
    }

    @Test("Demote swaps with the first stack window")
    func demote() throws {
        var space = Space(id: "s", windows: [w1, w2, w3])
        space.demote(w1, masterCount: 1)
        #expect(space.windows == [w2, w1, w3])
        // Already in stack: no-op.
        space.demote(w1, masterCount: 1)
        #expect(space.windows == [w2, w1, w3])
    }

    @Test("Spawn placements insert at the right position")
    func spawnPlacement() throws {
        var space = Space(id: "s", windows: [w1, w2])
        space.insert(w3, placement: .first)
        #expect(space.windows == [w3, w1, w2])
        space.insert(w4, placement: .last)
        #expect(space.windows == [w3, w1, w2, w4])
        // Relative placements anchor on the focused window
        // and fall back to appending without one.
        space.focused = w1
        space.insert(w5, placement: .beforeFocused)
        #expect(space.windows == [w3, w5, w1, w2, w4])
        space.insert(w6, placement: .afterFocused)
        #expect(space.windows == [w3, w5, w1, w6, w2, w4])
    }
}
