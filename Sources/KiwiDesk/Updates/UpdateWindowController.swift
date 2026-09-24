import AppKit
import Combine
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
    private var phaseWatch: AnyCancellable?

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
        phaseWatch = nil
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
        window.animationBehavior = .documentWindow
        window.setContentSize(
            NSSize(
                width: UpdateWindowMetrics.width,
                height: UpdateWindowMetrics.height(
                    fitting: fittingNotesHeight()
                )
            )
        )
        window.delegate = self
        phaseWatch = session.$phase.sink { [weak window] phase in
            Self.phaseChanged(to: phase, in: window)
        }
        return window
    }

    /// Greys the close button where the close does nothing (grey,
    /// don't hide), and speaks a phase the user did not cause.
    private static func phaseChanged(
        to phase: UpdateWindowPhase,
        in window: NSWindow?
    ) {
        window?.standardWindowButton(.closeButton)?.isEnabled =
            phase.closes
        guard let window, window.isVisible,
            let text = UpdateWindowFooter.announcement(phase)
        else { return }
        NSAccessibility.post(
            element: window,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
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
