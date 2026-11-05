import ApplicationServices
import CoreGraphics
import Testing
import os

@testable import KiwiDeskCore

/// A shrink near an edge is lifted only where macOS refuses it
/// (#2966). The table is the 2026-11-05 measurement: a 3200 x
/// 1440 screen around a 1728 x 1117 laptop, Firefox and Finder alike.
/// Screens are AX frames.
@Suite("The edge lift runs only where the band exists (#2966)")
@MainActor
struct EdgeBandGateTests {
    private let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    private let wide = CGSize(width: 3200, height: 1440)
    private let slot = CGRect(x: 16, y: 606.5, width: 840, height: 494.5)
    private let start = CGRect(x: 16, y: 602, width: 847, height: 499)

    private func other(_ x: CGFloat, _ y: CGFloat) -> CGRect {
        CGRect(origin: CGPoint(x: x, y: y), size: wide)
    }

    private func edges(
        _ frame: CGRect,
        beside neighbour: CGRect?,
        separateSpaces: Bool = false
    ) -> (bottom: Bool, right: Bool) {
        let band = EdgeBandWrite.bands(
            of: [laptop] + (neighbour.map { [$0] } ?? []),
            for: frame,
            separateSpaces: separateSpaces
        ).first { $0.screen == laptop }
        return (band?.bottom ?? false, band?.right ?? false)
    }

    private func window(x: CGFloat, y: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: 700, height: 460)
    }

    @Test("One screen has no band, separate Spaces on or off")
    func oneScreenHasNone() {
        for separate in [false, true] {
            let got = edges(
                window(x: 16, y: 641),
                beside: nil,
                separateSpaces: separate
            )
            #expect(got == (false, false))
        }
    }

    @Test("A wide screen below covers the bottom and reaches past the right")
    func belowCovers() {
        let got = edges(window(x: 16, y: 641), beside: other(0, 1117))
        #expect(got == (false, true))
    }

    @Test("A screen below offset bands only the span it does not cover")
    func belowOffsetBandsTheUncovered() {
        let below = other(800, 1117)
        #expect(edges(window(x: 16, y: 641), beside: below).bottom)
        #expect(edges(window(x: 514, y: 641), beside: below).bottom)
        #expect(!edges(window(x: 1012, y: 641), beside: below).bottom)
    }

    @Test("A taller screen right covers the right and reaches past the bottom")
    func rightCovers() {
        let got = edges(window(x: 1012, y: 641), beside: other(1728, 0))
        #expect(got == (true, false))
    }

    @Test("A screen right bands only the span it does not cover")
    func rightBandsTheUncovered() {
        let high = other(1728, -581)
        #expect(!edges(window(x: 1012, y: 50), beside: high).right)
        #expect(!edges(window(x: 1012, y: 328), beside: high).right)
        #expect(edges(window(x: 1012, y: 641), beside: high).right)
        #expect(!edges(window(x: 1012, y: 641), beside: high).bottom)
        let low = other(1728, 400)
        #expect(edges(window(x: 1012, y: 50), beside: low).right)
        #expect(edges(window(x: 1012, y: 328), beside: low).right)
        #expect(!edges(window(x: 1012, y: 641), beside: low).right)
    }

    /// Two neighbours sharing a span are not measured: the lift stays.
    @Test("A span shared by two neighbours keeps the band")
    func twoNeighboursKeepTheBand() {
        let half = CGSize(width: 800, height: 900)
        let bands = EdgeBandWrite.bands(
            of: [
                laptop,
                CGRect(origin: CGPoint(x: 0, y: 1117), size: half),
                CGRect(origin: CGPoint(x: 800, y: 1117), size: half),
            ],
            for: window(x: 500, y: 641),
            separateSpaces: false
        )
        #expect(bands.first { $0.screen == laptop }?.bottom == true)
    }

    @Test("Separate Spaces has no band on either edge")
    func separateSpacesHasNone() {
        let got = edges(
            window(x: 16, y: 641),
            beside: other(800, 1117),
            separateSpaces: true
        )
        #expect(got == (false, false))
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
            screens: [laptop, other(1000, 1117)],
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

    @Test("The applier writes plainly where a screen covers the span")
    func applierSkipsACoveredSpan() async throws {
        let calls = try await writes(
            screens: [laptop, other(0, 1117)],
            separateSpaces: false
        )
        #expect(calls == ["frame"])
    }

    @Test("The applier writes plainly under separate Spaces")
    func applierSkipsSeparateSpaces() async throws {
        let calls = try await writes(
            screens: [laptop, other(1000, 1117)],
            separateSpaces: true
        )
        #expect(calls == ["frame"])
    }
}
