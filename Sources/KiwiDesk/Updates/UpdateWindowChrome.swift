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
