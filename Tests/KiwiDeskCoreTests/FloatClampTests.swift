import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pure geometry that keeps a floating window from hiding
/// under a bar (#242; these are the top-edge cases of
/// `clampClear` — the other edges are covered in
/// `SpaceBarGeometryTests`). AX coordinates: y grows downward,
/// `minY` is the top edge.
@Suite("Float bar clamp, top edge")
struct FloatClampTests {
    // A 40 pt top strip carved from the top of the usable area.
    private let strip = CGRect(x: 0, y: 0, width: 1920, height: 40)

    @Test("A float under the top strip is pushed below it")
    func intrusionPushedDown() {
        let frame = CGRect(x: 100, y: 10, width: 300, height: 200)
        let clamped = AppBarGeometry.clampClear(
            frame,
            of: strip,
            edge: .top
        )
        // Top edge snaps to the strip's bottom; size and x unchanged.
        #expect(clamped.minY == strip.maxY)
        #expect(clamped.origin.x == 100)
        #expect(clamped.size == frame.size)
    }

    @Test("A float already clear of the strip is untouched")
    func clearIsNoOp() {
        let frame = CGRect(x: 100, y: 200, width: 300, height: 200)
        let clamped = AppBarGeometry.clampClear(
            frame,
            of: strip,
            edge: .top
        )
        #expect(clamped == frame)
    }

    @Test("A float flush at the strip's bottom is untouched")
    func flushIsNoOp() {
        let frame = CGRect(
            x: 0,
            y: strip.maxY,
            width: 300,
            height: 200
        )
        let clamped = AppBarGeometry.clampClear(
            frame,
            of: strip,
            edge: .top
        )
        #expect(clamped == frame)
    }

    @Test("A float only partly under the strip is still pushed")
    func partialIntrusionPushedDown() {
        // Top edge 5 pt above the strip bottom → intrudes.
        let frame = CGRect(x: 0, y: 35, width: 300, height: 200)
        let clamped = AppBarGeometry.clampClear(
            frame,
            of: strip,
            edge: .top
        )
        #expect(clamped.minY == strip.maxY)
    }

    @Test("A float within tolerance of clear is left alone")
    func withinToleranceIsNoOp() {
        // 1 pt under the strip bottom — inside clampTolerance, so
        // an app that lands a hair off isn't re-clamped every
        // retile (the #148 wobble precedent).
        let frame = CGRect(
            x: 0,
            y: strip.maxY - 1,
            width: 300,
            height: 200
        )
        let clamped = AppBarGeometry.clampClear(
            frame,
            of: strip,
            edge: .top
        )
        #expect(clamped == frame)
    }
}
