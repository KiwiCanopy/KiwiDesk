import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A strip walk keeps every glyph on its own chip (#2052): a
/// one-step focus move at a clamp boundary moves the window two
/// groups while the kept glyphs walk one cell, and the extra
/// glyph must fade in place rather than travel past the chip's
/// first or last cell over a neighbouring chip. Measured on the
/// laid-out chip — each glyph's resting frame and its walk's
/// slide — across every span and a run of counts, both ways.
///
/// Reduce Motion is pinned off INSIDE each test body through
/// `BarMotion.reducedOverride`, synchronously on the main actor
/// with a `defer` restore, so no other suite observes it: with it
/// on no walk plays and every start check passes unmeasured.
@Suite("Space Bar strip walk stays on the chip")
@MainActor
struct SpaceBarStripWalkBoundsTests {
    private static let depth: CGFloat = 32

    private func app(_ group: Int) -> SpaceBarItemView.App {
        SpaceBarItemView.App(
            name: "App\(group)",
            icon: NSImage(size: NSSize(width: 16, height: 16)),
            glyph: nil,
            focused: false,
            count: 1,
            windows: [WindowID(UInt32(group + 1))]
        )
    }

    private func makeView(span: Int) -> SpaceBarItemView {
        let length = SpaceBarItemView.autoLength(
            appCount: span,
            discs: 2,
            contentDepth: Self.depth,
            glyphGap: 0,
            ends: SpaceBarItemView.ends(
                look: SpaceBarLook(),
                depth: Self.depth,
                first: false,
                last: false,
                leadsWithIcon: false,
                endsInIcon: true,
                lone: nil
            )
        )
        return SpaceBarItemView(
            frame: CGRect(x: 0, y: 0, width: length, height: Self.depth)
        )
    }

    private func configure(
        _ view: SpaceBarItemView,
        window: Range<Int>,
        count: Int
    ) {
        var style = SpaceBarLook()
        style.glyphGap = 0
        let ids = { (groups: Range<Int>) in
            groups.map { WindowID(UInt32($0 + 1)) }
        }
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: window.map(app),
            active: true,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            ),
            before: .init(windows: ids(0..<window.lowerBound)),
            after: .init(windows: ids(window.upperBound..<count)),
            drawn: .init(window: window, count: count)
        )
        view.layout()
    }

    /// The slide a walk started on `view`: where it begins,
    /// relative to its resting frame.
    private func slide(of view: NSView) -> CGFloat {
        let step =
            view.layer?.animation(forKey: "kiwi.walk.slide")
            as? CABasicAnimation
        return (step?.fromValue as? NSValue)?.pointValue.x ?? 0
    }

    /// Every glyph a step from `old` to `new` draws or carries
    /// off starts and ends inside the chip's cells: the leading
    /// disc's cell through the trailing disc's.
    private func expectInside(
        span: Int,
        count: Int,
        from old: Range<Int>,
        to new: Range<Int>
    ) {
        let view = makeView(span: span)
        configure(view, window: old, count: count)
        // Where each glyph stood before the step: by group for the
        // kept ones, by view for the ones carried off.
        var oldCell: [Int: CGFloat] = [:]
        var oldView: [ObjectIdentifier: CGFloat] = [:]
        for (index, glyph) in view.appViews.enumerated() {
            oldCell[old.lowerBound + index] = glyph.frame.midX
            oldView[ObjectIdentifier(glyph)] = glyph.frame.midX
        }
        configure(view, window: new, count: count)
        let cell = view.cellLength
        guard let first = view.glyphTargets.first?.frame,
            let last = view.glyphTargets.last?.frame
        else {
            Issue.record("no glyphs drawn for \(new) of \(count)")
            return
        }
        let low = first.minX - (new.lowerBound > 0 ? cell : 0)
        let high = last.maxX + (new.upperBound < count ? cell : 0)
        let context =
            "span \(span), count \(count), \(old) -> \(new)"
        for glyph in view.appViews + view.leavingViews {
            let rest = glyph.frame.midX
            let start = rest + slide(of: glyph)
            for x in [rest, start] {
                #expect(
                    x >= low - 0.5 && x <= high + 0.5,
                    "\(context): a glyph at \(x) outside \(low)...\(high)"
                )
            }
        }
        // A step whose strips share a group walks a kept glyph;
        // without one every start above is its rest and measured
        // nothing. A jump sharing none walks nothing by design.
        let walks = view.appViews.contains {
            $0.layer?.animation(forKey: "kiwi.walk.slide") != nil
        }
        #expect(
            walks == old.overlaps(new),
            "\(context): a kept glyph walks only on a shared group"
        )
        // A kept glyph starts where it stood: the walk exactly,
        // not merely somewhere on the chip.
        var travel: CGFloat?
        for (index, glyph) in view.appViews.enumerated() {
            let group = new.lowerBound + index
            guard let was = oldCell[group] else { continue }
            let start = glyph.frame.midX + slide(of: glyph)
            #expect(
                abs(start - was) < 0.5,
                "\(context): group \(group) starts \(start), was \(was)"
            )
            travel = glyph.frame.midX - was
        }
        // A glyph carried off travels that same walk, held to the
        // chip's end cells, where it fades in place (#2052).
        guard let travel else { return }
        let ends = (low + cell / 2)...(high - cell / 2)
        for glyph in view.leavingViews {
            guard let was = oldView[ObjectIdentifier(glyph)] else {
                Issue.record("\(context): a leaving glyph never drawn")
                continue
            }
            let rest = min(
                max(was + travel, ends.lowerBound),
                ends.upperBound
            )
            #expect(
                abs(glyph.frame.midX - rest) < 0.5,
                "\(context): leaving at \(glyph.frame.midX), owed \(rest)"
            )
        }
    }

    /// Runs `body` with Reduce Motion pinned off, restored after.
    private func motionOn(_ body: () -> Void) {
        BarMotion.reducedOverride = false
        defer { BarMotion.reducedOverride = nil }
        body()
    }

    @Test("a one-step focus move keeps every glyph on the chip")
    func oneStepStaysInside() {
        LocalizationManager.shared.select("en")
        motionOn { sweepOneSteps() }
    }

    private func sweepOneSteps() {
        for span in SpaceBarStyle.glyphSpanRange {
            for count in (span + 3)...(span + 6) {
                let windows = (0..<count).map {
                    SpaceBarStrip.window(
                        count: count,
                        span: span,
                        anchor: $0
                    )
                }
                for (old, new) in zip(windows, windows.dropFirst())
                where old != new {
                    expectInside(
                        span: span,
                        count: count,
                        from: old,
                        to: new
                    )
                    expectInside(
                        span: span,
                        count: count,
                        from: new,
                        to: old
                    )
                }
            }
        }
    }

    /// The boundary step the sweep exists for, named so its
    /// failure reads on its own: nine groups at span 5, the focus
    /// stepping from the fourth group to the fifth and on to the
    /// end, where the window moves two groups in one step.
    @Test("the steps off and onto each end stay on the chip")
    func boundaryStepsStayInside() {
        LocalizationManager.shared.select("en")
        motionOn {
            expectInside(span: 5, count: 9, from: 0..<6, to: 2..<7)
            expectInside(span: 5, count: 9, from: 2..<7, to: 0..<6)
            expectInside(span: 5, count: 9, from: 2..<7, to: 3..<9)
            expectInside(span: 5, count: 9, from: 3..<9, to: 2..<7)
        }
    }
}
