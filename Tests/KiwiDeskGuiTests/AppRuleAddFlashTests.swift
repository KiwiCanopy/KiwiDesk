import AppKit
import Combine
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An App Rules add lights its row with search's landing flash
/// (#3490), on a row already in view and on one the page scrolls to.
/// The section is seeded as an add leaves it, its reveal asked;
/// `AppRuleAddRevealTests` holds that every add asks.
///
/// Main-actor spend: two hosted App Rules pages in an offscreen
/// window, each awaited in 10 ms sleeps until the model's
/// publisher has carried its flash.
@Suite("App Rules ▸ an add flashes its row (#3490)", .serialized)
@MainActor
struct AppRuleAddFlashTests {
    /// The one hang guard: a spin exits the moment the flash lands,
    /// so only a genuine hang reaches it.
    private static let hangGuard: TimeInterval = 30

    /// Forty float rules, more than the short window shows.
    private static let apps = (0..<40).map {
        String(format: "com.example.app%02d", $0)
    }

    /// The flash the reveal lit, and the page's scroll offset then.
    private func reveal(_ app: String) async -> (String?, CGFloat) {
        let model = makeTestModel(core: makeTestCore())
        model.config.floatRules = Self.apps
        let row = AppRulesSection.RowReveal(list: .float, key: app)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        let host = NSHostingView(
            rootView: AppRulesSection(model: model, revealing: row)
                .frame(width: 720, height: 420)
        )
        window.contentView = host
        let want = AppRulesSection.anchor(.float, app)
        // Every flash the model takes, as it takes it: a poll can
        // miss the 0.3 s hold under a loaded run.
        let seen = Seen()
        let watch = model.$nav.sink { nav in
            if let anchor = nav.flash?.anchor { seen.anchors.append(anchor) }
        }
        defer { watch.cancel() }
        let deadline = Date().addingTimeInterval(Self.hangGuard)
        // Awaited, never a run-loop spin: the reveal's own sleeps
        // resume on the main actor this test would otherwise hold.
        while !seen.anchors.contains(want) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        let lit = seen.anchors.contains(want) ? want : nil
        return (lit, scrollOffset(in: host))
    }

    /// The flashes a watch has seen, oldest first.
    private final class Seen {
        var anchors: [String] = []
    }

    private func scrollOffset(in view: NSView) -> CGFloat {
        if let scroll = view as? NSScrollView {
            return scroll.contentView.bounds.origin.y
        }
        return view.subviews.map(scrollOffset).max() ?? 0
    }

    @Test("a row above the fold flashes without the page moving")
    func inViewRowFlashes() async {
        LocalizationManager.shared.select("en")
        let (lit, offset) = await reveal(Self.apps[0])
        #expect(lit == AppRulesSection.anchor(.float, Self.apps[0]))
        #expect(offset < 1, "scrolled \(offset) pt for a row in view")
    }

    @Test("a row below the fold is scrolled to and flashes")
    func scrolledRowFlashes() async {
        LocalizationManager.shared.select("en")
        let last = Self.apps[Self.apps.count - 1]
        let (lit, offset) = await reveal(last)
        #expect(lit == AppRulesSection.anchor(.float, last))
        #expect(offset > 100, "scrolled only \(offset) pt")
    }
}
