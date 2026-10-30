import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Where the One-window pocket stands on a bar's edge (#2793): a
/// square as deep as the strip, one inner margin past its window
/// side, at Position along it and kept within it.
@Suite("Pocket inside the strip (#2793)")
struct PocketInsideTests {
    private let top = CGRect(x: 0, y: 4, width: 1000, height: 28)
    private let left = CGRect(x: 4, y: 0, width: 28, height: 800)

    @Test("on top it stands below the strip, at Position")
    func topStandsBelow() {
        let frame = KiwiCore.pocketInsideFrame(
            strip: top,
            edge: .top,
            position: 82,
            inner: 6
        )
        #expect(frame == CGRect(x: 806, y: 38, width: 28, height: 28))
    }

    @Test("on the bottom it stands above the strip")
    func bottomStandsAbove() {
        let strip = CGRect(x: 0, y: 868, width: 1000, height: 28)
        let frame = KiwiCore.pocketInsideFrame(
            strip: strip,
            edge: .bottom,
            position: 50,
            inner: 6
        )
        #expect(frame == CGRect(x: 486, y: 834, width: 28, height: 28))
    }

    @Test("on a side edge it stands toward the windows")
    func sideStandsInward() {
        let frame = KiwiCore.pocketInsideFrame(
            strip: left,
            edge: .left,
            position: 0,
            inner: 0
        )
        #expect(frame == CGRect(x: 32, y: 0, width: 28, height: 28))
        let right = CGRect(x: 1408, y: 0, width: 28, height: 800)
        let other = KiwiCore.pocketInsideFrame(
            strip: right,
            edge: .right,
            position: 100,
            inner: 4
        )
        #expect(other == CGRect(x: 1376, y: 772, width: 28, height: 28))
    }

    @Test("Position past either end keeps it within the strip")
    func clampsToTheStrip() {
        let end = KiwiCore.pocketInsideFrame(
            strip: top,
            edge: .top,
            position: 100,
            inner: 0
        )
        #expect(end.maxX == top.maxX)
        let start = KiwiCore.pocketInsideFrame(
            strip: top,
            edge: .top,
            position: -20,
            inner: 0
        )
        #expect(start.minX == top.minX)
    }
}
