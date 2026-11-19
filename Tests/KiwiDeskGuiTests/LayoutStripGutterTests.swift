import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Layout Defaults lays out at one width whether a pick's card
/// scrolls the page or fits it (#3503): under a legacy scroller the
/// strip keeps one viewport, so its tiles never cross the fit line
/// on a pick. Measured on the hosted page at a width just past the
/// fit line, the strip found by its sideways scroll view.
///
/// Main-actor spend: four hosted Layout Defaults pages in an
/// offscreen window, each polled by awaited 50 ms sleeps until the
/// strip has settled.
@Suite("Layout Defaults keeps one width (#3503)", .serialized)
@MainActor
struct LayoutStripGutterTests {
    /// The one hang guard: a wait exits the moment the strip has
    /// settled, so only a genuine hang reaches it.
    private static let hangGuard: TimeInterval = 30
    private static let steadyPolls = 6
    /// Past the six tiles' fit line on a page that fits, short of
    /// it on one a legacy scroller narrows: measured 2026-11-19,
    /// the strip's viewport is 864 pt there against 847 pt.
    private static let width: CGFloat = 880

    /// The strip's viewport width once it stops moving.
    private func stripViewport(
        height: CGFloat,
        style: NSScroller.Style? = nil
    ) async -> CGFloat? {
        let model = makeTestModel()
        model.nav.layoutModeTab = .monocle
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: Self.width,
                height: height
            ),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        let host = NSHostingView(
            rootView: LayoutDefaultsSection(model: model)
                .environment(\.scrollerStyleForced, style)
                .frame(width: Self.width, height: height, alignment: .top)
        )
        window.contentView = host
        var last: CGFloat?
        var steady = 0
        let deadline = Date().addingTimeInterval(Self.hangGuard)
        repeat {
            try? await Task.sleep(nanoseconds: 50_000_000)
            let now = strip(in: host)?.contentView.bounds.width
            steady = now != nil && now == last ? steady + 1 : 0
            last = now
        } while steady < Self.steadyPolls && Date() < deadline
        return last
    }

    /// The page's one sideways scroll view: the strip.
    private func strip(in host: NSView) -> NSScrollView? {
        var found: NSScrollView?
        func walk(_ view: NSView) {
            if let scroll = view as? NSScrollView,
                !scroll.hasVerticalScroller
            {
                found = scroll
            }
            view.subviews.forEach(walk)
        }
        walk(host)
        return found
    }

    /// Under this Mac's scroller: a short window scrolls the page,
    /// a tall one fits it, and the strip is as wide in both. Only a
    /// legacy host can red it; the forced pair below reds anywhere.
    @Test("the strip is as wide whether the page scrolls or fits")
    func oneViewport() async {
        LocalizationManager.shared.select("en")
        let scrolls = await stripViewport(height: 600)
        let fits = await stripViewport(height: 2600)
        #expect(scrolls != nil && fits != nil)
        #expect(scrolls == fits, "scrolls \(scrolls ?? 0), fits \(fits ?? 0)")
    }

    /// A page that fits under a legacy scroller lays out at the
    /// width a showing scroller leaves; under an overlay scroller,
    /// at the full width. Both styles are forced, so either kind of
    /// host runs both.
    @Test("a fitting page keeps a legacy scroller's width")
    func fittingPageKeepsTheGutter() async throws {
        LocalizationManager.shared.select("en")
        let overlay = try #require(
            await stripViewport(height: 2600, style: .overlay)
        )
        let legacy = try #require(
            await stripViewport(height: 2600, style: .legacy)
        )
        #expect(
            legacy + LegacyScrollerGutter.width == overlay,
            "legacy \(legacy), overlay \(overlay)"
        )
    }
}
