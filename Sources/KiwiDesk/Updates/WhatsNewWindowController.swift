import AppKit
import KiwiDeskCore

/// "What's new in X" (#1542 ruling ▸ After the update): the same
/// window with one Done. Its close is Done too. A spotlight row's
/// "Show me" hides it without answering it (#2038 ruling ▸
/// handoff); whose trail that is, and when it ends, is
/// `WhatsNewCoordinator`'s. With a `menu` it carries the release
/// menu (#2308).
@MainActor
final class WhatsNewWindowController: NSObject, NSWindowDelegate {
    let offer: UpdateOffer
    /// Internal so a test sees what the relaunch handed on.
    let narration: BootNarration?
    /// Internal so a test sees what the window was handed.
    let next: NextOnMyList?
    /// The release menu; nil draws none.
    let menu: WhatsNewMenu?
    /// The notes on screen — `offer` until the menu picks another
    /// release; what a "Show me" hands off.
    private(set) var shown: UpdateOffer
    private let done: () -> Void
    private let showMe: SpotlightShowMe
    private var window: NSWindow?
    /// Whether a "Show me" has the window hidden, unanswered —
    /// what a Settings close asks before re-presenting it.
    private(set) var hidden = false

    /// Puts the window forward; a test records it instead.
    var fronts: (NSWindow) -> Void = { NSApp.forceFront($0) }
    /// Takes the window off screen; a test records it instead.
    var hides: (NSWindow) -> Void = { $0.orderOut(nil) }

    /// `offer` is the menu's opening when there is a menu.
    init(
        offer: UpdateOffer,
        narration: BootNarration?,
        next: NextOnMyList?,
        menu: WhatsNewMenu? = nil,
        showMe: @escaping SpotlightShowMe,
        done: @escaping () -> Void
    ) {
        self.offer = menu?.offer ?? offer
        self.shown = self.offer
        self.narration = narration
        self.next = next
        self.menu = menu
        self.showMe = showMe
        self.done = done
        super.init()
    }

    /// Brings it forward: the user started this launch, asked
    /// for it from the quick menu or Home, or came back from
    /// Settings — where a hidden window keeps its place, tab and
    /// scroll.
    func present() {
        let window: NSWindow
        if let existing = self.window {
            window = existing
        } else {
            window = makeWindow()
            window.center()
        }
        hidden = false
        fronts(window)
    }

    /// Hides the window without answering it (#2038).
    func hide() {
        guard let window else { return }
        hidden = true
        hides(window)
    }

    /// The menu picked another release.
    func didShow(_ offer: UpdateOffer) {
        shown = offer
    }

    /// Internal so a test takes the production window and hands
    /// it the close.
    func makeWindow() -> NSWindow {
        let finished: () -> Void = { [weak self] in self?.finish() }
        let window: NSWindow
        if let menu {
            window = UpdateWindowChrome.window(
                menu: menu,
                narration: narration,
                next: next,
                showMe: showMe,
                done: finished
            ) { [weak self] in self?.didShow($0) }
        } else {
            window = UpdateWindowChrome.window(
                offer: offer,
                mode: .whatsNew(
                    narration: narration,
                    next: next,
                    done: finished
                ),
                showMe: showMe
            )
        }
        window.delegate = self
        self.window = window
        return window
    }

    /// Done — the button, the close, or the trail's ×.
    func finish() {
        window?.delegate = nil
        window?.orderOut(nil)
        window = nil
        hidden = false
        done()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        finish()
        return false
    }
}
