import AppKit
import ApplicationServices
import CoreGraphics
import Testing
import os

@testable import KiwiDeskCore

/// A shrink near an edge is lifted only where macOS refuses it
/// (#2966): another screen reaches past that edge, and for the
/// bottom, separate Spaces is off. Screens are AX frames.
@Suite("The edge lift runs only where the band exists (#2966)")
@MainActor
struct EdgeBandGateTests {
    private let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private var lower: CGRect { laptop.offsetBy(dx: 0, dy: laptop.height) }
    private var beside: CGRect { laptop.offsetBy(dx: laptop.width, dy: 0) }
    private let slot = CGRect(x: 16, y: 606.5, width: 840, height: 494.5)
    private let start = CGRect(x: 16, y: 602, width: 847, height: 499)

    @Test("One screen has no band, separate Spaces on or off")
    func oneScreenHasNone() {
        for separate in [false, true] {
            let bands = EdgeBandWrite.bands(
                of: [laptop],
                separateSpaces: separate
            )
            #expect(bands.isEmpty)
        }
    }

    @Test("A screen below gives the upper one a bottom band, no more")
    func lowerScreenBandsTheUpper() {
        let bands = EdgeBandWrite.bands(
            of: [laptop, lower],
            separateSpaces: false
        )
        #expect(
            bands == [EdgeBand(screen: laptop, bottom: true, right: false)]
        )
    }

    @Test("Separate Spaces removes the bottom band and keeps the right")
    func separateSpacesKeepsTheRight() {
        let bands = EdgeBandWrite.bands(
            of: [laptop, lower, beside],
            separateSpaces: true
        )
        #expect(
            bands.map(\.screen) == [laptop, lower]
        )
        #expect(bands.allSatisfy { !$0.bottom && $0.right })
    }

    /// Where along an edge macOS refuses depends on the neighbours'
    /// extent, so a screen past the edge counts anywhere along it.
    @Test("A screen past the edge counts without facing the window")
    func diagonalNeighbourCounts() {
        let diagonal = laptop.offsetBy(dx: laptop.width, dy: 500)
        let bands = EdgeBandWrite.bands(
            of: [laptop, diagonal],
            separateSpaces: false
        )
        #expect(
            bands == [EdgeBand(screen: laptop, bottom: true, right: true)]
        )
    }

    @Test("A frame near an edge with no band names nothing")
    func edgeWithoutBandNamesNothing() {
        let rightOnly = EdgeBand(screen: laptop, bottom: false, right: true)
        let bottomOnly = EdgeBand(screen: laptop, bottom: true, right: false)
        let atBottom = slot
        let atRight = CGRect(x: 872, y: 16, width: 840, height: 566)
        #expect(EdgeBandWrite.band(for: atBottom, among: [rightOnly]) == nil)
        #expect(EdgeBandWrite.band(for: atRight, among: [bottomOnly]) == nil)
        #expect(
            EdgeBandWrite.band(for: atBottom, among: [bottomOnly])
                == bottomOnly
        )
        #expect(
            EdgeBandWrite.band(for: atRight, among: [rightOnly]) == rightOnly
        )
    }

    /// A corner window with one band: the other axis must not jump.
    @Test("A lift moves only the axis whose edge has a band")
    func liftMovesOneAxis() {
        let target = CGRect(x: 872, y: 606.5, width: 840, height: 494.5)
        let current = CGRect(x: 866, y: 602, width: 846, height: 499)
        let right = EdgeBandWrite.liftedOrigin(
            target: target,
            current: current,
            band: EdgeBand(screen: laptop, bottom: false, right: true)
        )
        #expect(right == CGPoint(x: 1728 - EdgeBandWrite.band - 846, y: 602))
        let bottom = EdgeBandWrite.liftedOrigin(
            target: target,
            current: current,
            band: EdgeBand(screen: laptop, bottom: true, right: false)
        )
        #expect(bottom == CGPoint(x: 866, y: 1117 - EdgeBandWrite.band - 499))
    }

    /// What the applier sends, after `start`'s frame.
    private func writes(
        screens: [CGRect],
        separateSpaces: Bool
    ) async throws -> [String] {
        let calls = OSAllocatedUnfairLock<[String]>(initialState: [])
        let applier = FrameApplier()
        let element = AXUIElementCreateApplication(getpid())
        let start = start
        applier.elementProvider = { _ in element }
        applier.screenFrames = { screens }
        applier.separateSpaces = { separateSpaces }
        applier.writer = FrameWriter(
            setFrame: { _, _ in calls.withLock { $0.append("frame") } },
            setPosition: { _, _ in calls.withLock { $0.append("position") } },
            writeEUI: { _, _ in },
            frame: { _ in
                calls.withLock { $0.append("read") }
                return start
            }
        )
        applier.applyInstant(WindowID(1), slot, setSize: true)
        // A generous guard, never a tight deadline (#344).
        for _ in 0..<500
        where calls.withLock({ !$0.contains("frame") }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        return calls.withLock { $0 }
    }

    @Test("The applier lifts with a screen past the edge")
    func applierLiftsWhereTheBandIs() async throws {
        let calls = try await writes(
            screens: [laptop, lower],
            separateSpaces: false
        )
        #expect(calls == ["read", "position", "frame"])
    }

    @Test("The applier writes plainly on one screen")
    func applierSkipsOneScreen() async throws {
        let calls = try await writes(
            screens: [laptop],
            separateSpaces: false
        )
        #expect(calls == ["frame"])
    }

    @Test("The applier writes plainly under separate Spaces")
    func applierSkipsSeparateSpaces() async throws {
        let calls = try await writes(
            screens: [laptop, lower],
            separateSpaces: true
        )
        #expect(calls == ["frame"])
    }

    @Test("The engine hands the applier macOS's separate Spaces answer")
    func engineWiresSeparateSpaces() {
        let engine = TilingEngine()
        #expect(
            engine.applier.separateSpaces()
                == NSScreen.screensHaveSeparateSpaces
        )
    }
}
