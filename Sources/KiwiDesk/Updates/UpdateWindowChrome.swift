import AppKit
import KiwiDeskCore
import SwiftUI

/// The one window every update answer shares (#1542, #1849):
/// titled, not tiled — it carries no `OwnWindowTiling` mark — not
/// miniaturizable, closable, `UpdateWindowMetrics.width` wide and
/// opening at its content between the ruled heights.
@MainActor
enum UpdateWindowChrome {
    static func window(
        offer: UpdateOffer,
        mode: UpdateWindowMode
    ) -> NSWindow {
        window(
            root: UpdateWindowView(offer: offer, mode: mode),
            // The probe has no window, so no title-bar inset.
            height: UpdateWindowMetrics.height(
                fitting: fittingHeight(offer: offer, mode: mode)
                    + UpdateWindowMetrics.titleBar
            )
        )
    }

    /// The window around any of its states, at `height`.
    static func window<Root: View>(root: Root, height: CGFloat) -> NSWindow {
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
            NSSize(width: UpdateWindowMetrics.width, height: height)
        )
        return window
    }

    /// The notes' natural height at the window's width, measured
    /// once so the window opens at its content and scrolls beyond.
    private static func fittingHeight(
        offer: UpdateOffer,
        mode: UpdateWindowMode
    ) -> CGFloat {
        let unscrolled = UpdateWindowView(
            offer: offer,
            mode: mode,
            measuring: true
        )
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
    private var window: NSWindow?

    init(
        offer: UpdateOffer,
        narration: BootNarration?,
        next: NextOnMyList?,
        done: @escaping () -> Void
    ) {
        self.offer = offer
        self.narration = narration
        self.next = next
        self.done = done
        super.init()
    }

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
            }
        )
        window.delegate = self
        self.window = window
        return window
    }

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
