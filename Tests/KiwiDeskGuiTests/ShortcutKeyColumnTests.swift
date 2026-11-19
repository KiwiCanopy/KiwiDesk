import AppKit
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Shortcuts ▸ Built-in and Mouse & Trackpad draw their key wells in
/// one column (#3491): a gesture row ends in a trash, so a
/// trash-less keyboard row holds the slot, and the wells end at one
/// x, under a legacy scroller too, whose gutter a page that fits
/// holds. Measured on the hosted page at the narrowest Settings
/// width, each well found by its focus ring at the well's own width.
///
/// Main-actor spend: four hosted Shortcuts pages in an offscreen
/// window, each polled by awaited 50 ms sleeps until its wells have
/// settled.
@Suite("Shortcuts key column (#3491)", .serialized)
@MainActor
struct ShortcutKeyColumnTests {
    /// The one hang guard: a wait exits the moment its wells have
    /// settled, so only a genuine hang reaches it.
    private static let hangGuard: TimeInterval = 30

    /// Polls that must read the same wells before they count as
    /// laid out: a page still building its parts or settling its
    /// layout reads a moving set.
    private static let steadyPolls = 6

    /// The wells' trailing edges on `segment`, at least `least`,
    /// once they stop moving.
    private func wellEnds(
        _ segment: ShortcutsSegment,
        least: Int,
        legacy: Bool = false
    ) async -> [CGFloat] {
        let model = makeTestModel()
        model.nav.shortcutsSegment = segment
        let width = SettingsWidthClass.minimum
        // Tall enough that Mouse & Trackpad fits and Built-in scrolls.
        let height: CGFloat = 2400
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        let host = NSHostingView(
            rootView: ShortcutsSection(model: model)
                .environment(\.legacyScrollerForced, legacy)
                .frame(width: width, height: height, alignment: .top)
        )
        window.contentView = host
        var ends: [CGFloat] = []
        var steady = 0
        let deadline = Date().addingTimeInterval(Self.hangGuard)
        // Awaited, never a run-loop spin: the page builds its parts
        // in tasks on the main actor this test would otherwise hold.
        repeat {
            try? await Task.sleep(nanoseconds: 50_000_000)
            let now = wells(in: host).map(\.maxX).sorted()
            steady = now == ends && now.count >= least ? steady + 1 : 0
            ends = now
        } while steady < Self.steadyPolls && Date() < deadline
        return ends
    }

    /// The record wells: the focus rings at the page's commonest
    /// width at least the well's floor, which every empty or short
    /// chord's well shares; a long chord's wider well and the
    /// pop-ups, fewer, fall outside it.
    private func wells(in host: NSView) -> [CGRect] {
        var out: [CGRect] = []
        func walk(_ view: NSView) {
            if String(describing: type(of: view)) == "_FocusRingView" {
                out.append(view.convert(view.bounds, to: host))
            }
            view.subviews.forEach(walk)
        }
        walk(host)
        let floor = KeyRecorderField.labelMinWidth
        var tally: [CGFloat: Int] = [:]
        for ring in out where ring.width >= floor {
            tally[(ring.width * 2).rounded() / 2, default: 0] += 1
        }
        guard let well = tally.max(by: { $0.value < $1.value })?.key
        else { return [] }
        return out.filter { abs($0.width - well) < 0.5 }
    }

    /// In a window tall enough that Mouse & Trackpad fits while
    /// Built-in scrolls, the wells share one x under the scroller
    /// this Mac shows: CI's, with no trackpad, is legacy, and a
    /// legacy scroller's gutter is held on the page that fits.
    @Test("Built-in and Mouse & Trackpad wells end at one x")
    func oneKeyColumn() async {
        LocalizationManager.shared.select("en")
        let keys = await wellEnds(.builtIn, least: 10)
        let gestures = await wellEnds(.mouse, least: 5)
        #expect(keys.count >= 10, "Built-in drew \(keys.count) wells")
        #expect(gestures.count >= 5, "Mouse drew \(gestures.count) wells")
        let all = Set((keys + gestures).map { ($0 * 2).rounded() / 2 })
        #expect(
            all.count == 1,
            Comment(
                rawValue: "Built-in wells end at \(Set(keys).sorted()), "
                    + "Mouse wells at \(Set(gestures).sorted())"
            )
        )
    }

    /// A page that fits under a legacy scroller holds the scroller's
    /// width, so its wells stand where a scrolling page's do. The
    /// override makes this Mac's overlay scroller read as legacy; on
    /// a Mac that already shows legacy ones it changes nothing.
    @Test("a fitting page holds a legacy scroller's gutter")
    func fittingPageHoldsTheGutter() async {
        LocalizationManager.shared.select("en")
        let plain = Set(await wellEnds(.mouse, least: 5))
        let forced = Set(await wellEnds(.mouse, least: 5, legacy: true))
        let already = NSScroller.preferredScrollerStyle == .legacy
        let shift = already ? 0 : LegacyScrollerGutter.width
        #expect(plain.count == 1 && forced.count == 1)
        #expect(
            forced.map { $0 + shift } == Array(plain),
            "fitting page's wells at \(forced.sorted()), plain \(plain)"
        )
    }
}
