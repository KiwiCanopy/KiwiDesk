import AppKit
import KiwiDeskCore
import SwiftUI

/// The one window every update answer shares (#1542, #1849):
/// titled, not tiled — it carries no `OwnWindowTiling` mark — not
/// miniaturizable, closable, `UpdateWindowMetrics.width` wide and
/// opening at its content between the ruled heights.
@MainActor
enum UpdateWindowChrome {
    /// `showMe` is a spotlight row's hand-off to Settings (#2038),
    /// which only What's new offers.
    static func window(
        offer: UpdateOffer,
        mode: UpdateWindowMode,
        showMe: SpotlightShowMe? = nil
    ) -> NSWindow {
        window(
            root: UpdateWindowView(offer: offer, mode: mode)
                .environment(\.spotlightShowMe, showMe),
            // The probe has no window, so no title-bar inset.
            height: UpdateWindowMetrics.height(
                fitting: fittingHeight(
                    offer: offer,
                    mode: mode,
                    showMe: showMe
                ) + UpdateWindowMetrics.titleBar
            )
        )
    }

    /// The window around any of its states, at `height` and, for a
    /// state narrower than the notes, `width`.
    static func window<Root: View>(
        root: Root,
        height: CGFloat,
        width: CGFloat = UpdateWindowMetrics.width
    ) -> NSWindow {
        let hosting = NSHostingController(
            rootView: LocaleScopedRoot { root }
                .environmentObject(LocalizationManager.shared)
        )
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // The glass ground draws the window's backdrop (#1849).
        window.isOpaque = false
        window.backgroundColor = .clear
        window.title = L("update.window.window_title", "KiwiDesk Update")
        window.isReleasedWhenClosed = false
        window.animationBehavior = .documentWindow
        window.setContentSize(
            NSSize(width: width, height: height)
        )
        return window
    }

    /// The notes' natural height at the window's width, measured
    /// once so the window opens at its content and scrolls beyond.
    private static func fittingHeight(
        offer: UpdateOffer,
        mode: UpdateWindowMode,
        showMe: SpotlightShowMe?
    ) -> CGFloat {
        let unscrolled = UpdateWindowView(
            offer: offer,
            mode: mode,
            measuring: true
        )
        .environment(\.spotlightShowMe, showMe)
        let probe = NSHostingView(
            rootView: LocaleScopedRoot { unscrolled }
                .environmentObject(LocalizationManager.shared)
        )
        return probe.fittingSize.height
    }
}

/// "What's new in X" (#1542 ruling ▸ After the update): the same
/// window with one Done. Its close is Done too.
@MainActor
final class WhatsNewWindowController: NSObject, NSWindowDelegate {
    let offer: UpdateOffer
    /// Internal so a test sees what the relaunch handed on.
    let narration: BootNarration?
    /// Internal so a test sees what the window was handed.
    let next: NextOnMyList?
    private let done: () -> Void
    /// Hands a spotlight row's trail to Settings (#2038 ruling ▸
    /// handoff); the coordinator's, set by the app.
    private let showsInSettings: (WhatsNewTrail) -> Void
    private var window: NSWindow?

    init(
        offer: UpdateOffer,
        narration: BootNarration?,
        next: NextOnMyList?,
        showsInSettings: @escaping (WhatsNewTrail) -> Void = { _ in },
        done: @escaping () -> Void
    ) {
        self.offer = offer
        self.narration = narration
        self.next = next
        self.showsInSettings = showsInSettings
        self.done = done
        super.init()
    }

    /// Whether the window is on screen — false while a "Show me"
    /// has it hidden behind Settings.
    var isShown: Bool { window?.isVisible ?? false }

    /// Brings it forward: the user started this launch, or asked
    /// for it from the quick menu.
    func present() {
        let window = self.window ?? makeWindow()
        if !window.isVisible { window.center() }
        NSApp.forceFront(window)
    }

    /// Internal so a test takes the production window and hands
    /// it the close.
    func makeWindow() -> NSWindow {
        let window = UpdateWindowChrome.window(
            offer: offer,
            mode: .whatsNew(narration: narration, next: next) {
                [weak self] in
                self?.finish()
            },
            showMe: { [weak self] entry in self?.showMe(entry) }
        )
        window.delegate = self
        self.window = window
        return window
    }

    /// "Show me" (#2038 ruling ▸ handoff): hides the window
    /// WITHOUT finishing it — this controller stays retained, so
    /// its tab and scroll survive — and hands Settings the trail
    /// back, which lands on the row's control.
    func showMe(_ entry: UpdateNotesDigest.SpotlightEntry) {
        guard
            let trail = WhatsNewTrail(
                spotlight: offer.digest?.spotlight ?? [],
                picked: entry,
                landing: SpotlightLanding.anchor(for:),
                back: { [weak self] in self?.reshow() },
                dismiss: { [weak self] in self?.finish() }
            )
        else { return }
        window?.orderOut(nil)
        showsInSettings(trail)
    }

    /// Back from Settings: the same window where it was, on the
    /// same tab and scroll.
    func reshow() {
        guard let window else { return }
        reshows(window)
    }

    /// Brings the hidden window back; a test records it instead.
    var reshows: (NSWindow) -> Void = { NSApp.forceFront($0) }

    private func finish() {
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
        done()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finish()
        return false
    }
}
