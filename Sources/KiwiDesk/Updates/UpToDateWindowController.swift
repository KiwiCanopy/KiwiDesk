import AppKit

/// The update window's answer to a check that found nothing newer
/// (#1849): the running version's notes and "Next on my list",
/// one Done. Sparkle waits on the acknowledgement until it closes.
@MainActor
final class UpToDateWindowController: NSObject, NSWindowDelegate {
    let offer: UpdateOffer
    /// Internal so a test sees what the window was handed.
    let next: NextOnMyList?
    private let done: () -> Void
    private var window: NSWindow?

    init(
        offer: UpdateOffer,
        next: NextOnMyList?,
        done: @escaping () -> Void
    ) {
        self.offer = offer
        self.next = next
        self.done = done
        super.init()
    }

    /// Brings it forward: the user asked for the check.
    func present() {
        let window = self.window ?? makeWindow()
        if !window.isVisible { window.center() }
        NSApp.forceFront(window)
    }

    /// Internal so a test takes the production window.
    func makeWindow() -> NSWindow {
        let window = UpdateWindowChrome.window(
            offer: offer,
            mode: .upToDate(next: next) { [weak self] in self?.finish() }
        )
        window.delegate = self
        self.window = window
        return window
    }

    /// Closes without answering Sparkle — its session already
    /// ended or another window replaces this one.
    func close() {
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
    }

    private func finish() {
        close()
        done()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finish()
        return false
    }
}
