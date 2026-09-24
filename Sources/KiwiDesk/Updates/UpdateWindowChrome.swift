import AppKit
import KiwiDeskCore
import SwiftUI

/// The one window both update surfaces share (#1542): titled, not
/// tiled — it carries no `OwnWindowTiling` mark — not
/// miniaturizable, closable, 560 pt wide and opening at its
/// content between the ruled heights.
@MainActor
enum UpdateWindowChrome {
    static func window(
        offer: UpdateOffer,
        mode: UpdateWindowMode
    ) -> NSWindow {
        let hosting = NSHostingController(
            rootView: LocaleScopedRoot {
                UpdateWindowView(offer: offer, mode: mode)
            }
            .environmentObject(LocalizationManager.shared)
        )
        hosting.sizingOptions = []
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = L("update.window.window_title", "KiwiDesk Update")
        window.isReleasedWhenClosed = false
        window.animationBehavior = .documentWindow
        window.setContentSize(
            NSSize(
                width: UpdateWindowMetrics.width,
                // The probe has no window, so no title-bar inset.
                height: UpdateWindowMetrics.height(
                    fitting: fittingHeight(offer: offer, mode: mode)
                        + UpdateWindowMetrics.titleBar
                )
            )
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
    private let done: () -> Void
    private var window: NSWindow?

    init(offer: UpdateOffer, done: @escaping () -> Void) {
        self.offer = offer
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
            mode: .whatsNew { [weak self] in self?.finish() }
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
