import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure decision behind the traveler re-home (#1217): which
/// screen a frame sits on, whether that is already the
/// destination, and the proportional target when it is not.
@Suite("Traveler re-home decision (#1217)")
struct TravelerRehomeTests {
    private let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let right = CGRect(x: 1000, y: 0, width: 500, height: 400)

    @Test("a frame on another screen is moved proportionally")
    func movedProportionally() {
        let frame = CGRect(x: 100, y: 100, width: 400, height: 200)
        let target = TravelerRehome.target(
            frame: frame,
            screens: [left, right],
            destination: right,
            scaleSize: true
        )
        #expect(
            target
                == FloatReanchor.target(
                    frame: frame,
                    from: left,
                    to: right,
                    scaleSize: true
                )
        )
        #expect(target.map { right.contains($0) } == true)
    }

    @Test("a frame already on the destination moves nothing")
    func sameScreenMovesNothing() {
        let frame = CGRect(x: 1100, y: 50, width: 200, height: 100)
        #expect(
            TravelerRehome.target(
                frame: frame,
                screens: [left, right],
                destination: right,
                scaleSize: true
            ) == nil
        )
    }

    /// The screen the frame OVERLAPS MOST is its source — the
    /// `screen(containing:)` rule — so a frame straddling the seam
    /// is judged by where most of it sits.
    @Test("a straddling frame belongs to the screen it mostly sits on")
    func straddlingFrameByOverlap() {
        let frame = CGRect(x: 900, y: 0, width: 400, height: 100)
        #expect(
            TravelerRehome.target(
                frame: frame,
                screens: [left, right],
                destination: right,
                scaleSize: false
            ) == nil
        )
        let mostlyLeft = CGRect(x: 700, y: 0, width: 400, height: 100)
        #expect(
            TravelerRehome.target(
                frame: mostlyLeft,
                screens: [left, right],
                destination: right,
                scaleSize: false
            ) != nil
        )
    }

    @Test("a frame on no screen moves nothing")
    func offScreenMovesNothing() {
        let frame = CGRect(x: 5000, y: 5000, width: 10, height: 10)
        #expect(
            TravelerRehome.target(
                frame: frame,
                screens: [left, right],
                destination: right,
                scaleSize: true
            ) == nil
        )
    }

    @Test("the size scales only when asked")
    func scaleSizeIsPassedThrough() {
        let frame = CGRect(x: 100, y: 100, width: 400, height: 200)
        let kept = TravelerRehome.target(
            frame: frame,
            screens: [left, right],
            destination: right,
            scaleSize: false
        )
        #expect(kept?.size == frame.size)
        let scaled = TravelerRehome.target(
            frame: frame,
            screens: [left, right],
            destination: right,
            scaleSize: true
        )
        #expect(scaled?.width == 200)
        #expect(scaled?.height == 100)
    }
}
