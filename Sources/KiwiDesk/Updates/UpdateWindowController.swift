import AppKit
import KiwiDeskCore
import SwiftUI

/// Owns the update window for one offer (#1542): titled, not
/// tiled — it carries no `OwnWindowTiling` mark — not
/// miniaturizable, closable. The close (button, ⌘W) is the
/// footer's Later or Cancel, and refused where neither applies.
@MainActor
final class UpdateWindowController: NSObject, NSWindowDelegate {
    let session: UpdateSession
    let offer: UpdateOffer
    private var window: NSWindow?

    init(offer: UpdateOffer, session: UpdateSession) {
        self.offer = offer
        self.session = session
        super.init()
    }

    /// Shows the window and brings KiwiDesk forward: the window
    /// finishes what the user began (gui.md ▸ comes forward).
    func present() {
        let window = self.window ?? makeWindow()
        self.window = window
        if !window.isVisible { window.center() }
        NSApp.forceFront(window)
    }

    func hide() {
        window?.orderOut(nil)
    }

    func close() {
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
    }

    /// Internal so a test takes the production window — its style
    /// mask is what the ruling is about.
    func makeWindow() -> NSWindow {
        let hosting = NSHostingController(
            rootView: LocaleScopedRoot {
                UpdateWindowView(offer: offer, session: session)
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
        window.animationBehavior = .alertPanel
        window.setContentSize(
            NSSize(
                width: UpdateWindowMetrics.width,
                height: UpdateWindowMetrics.height(
                    fitting: fittingNotesHeight()
                )
            )
        )
        window.delegate = self
        return window
    }

    /// The notes' natural height at the window's width, measured
    /// once so the window opens at its content between the ruled
    /// bounds and scrolls beyond them.
    private func fittingNotesHeight() -> CGFloat {
        let probe = NSHostingView(
            rootView: LocaleScopedRoot { unscrolled }
                .environmentObject(LocalizationManager.shared)
        )
        return probe.fittingSize.height
    }

    private var unscrolled: UpdateWindowView {
        UpdateWindowView(offer: offer, session: session, measuring: true)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        session.later()
        return false
    }
}
