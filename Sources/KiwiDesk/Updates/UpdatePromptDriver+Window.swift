import AppKit
import Sparkle

/// The driver's own-window plumbing (#1542): building the offer
/// from the loaded appcast and opening, showing and closing the
/// window the overrides route to.
extension UpdatePromptDriver {
    /// The found offer on a plain flag — Sparkle's state object
    /// cannot be built outside Sparkle, so the routing is tested
    /// through here.
    func showUpdateFound(
        _ item: SUAppcastItem,
        userInitiated: Bool,
        stage: SPUUserUpdateStage,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        // Sparkle's "Checking…" window closes with the offer; its
        // own close is private, and this is the public door to it.
        super.dismissUpdateInstallation()
        if let window, window.session.retry == .checking,
            window.offer.build == item.versionString
        {
            return window.session.refound(reply: reply)
        }
        openWindow(for: item, stage: stage, reply: reply)
        if prompts.offerArrived(userInitiated: userInitiated) {
            presentWindow()
        }
    }

    func openWindow(
        for item: SUAppcastItem,
        stage: SPUUserUpdateStage,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        closeWindow()
        let session = UpdateSession(
            reply: reply,
            installsFrom: Self.installsFrom(stage)
        )
        let window = UpdateWindowController(
            offer: UpdateOffer.make(
                item: item,
                loaded: loadedItems,
                host: Bundle.main
            ),
            session: session
        )
        session.startCheck = { [weak self] in self?.startCheck() }
        session.hide = { [weak window] in window?.hide() }
        session.end = { [weak self] in self?.closeWindow() }
        session.onInstall = { [record = seenRecord] in
            record.markSeen(item.versionString)
        }
        self.window = window
    }

    /// Shows the window: the offer got the user's attention.
    func presentWindow() {
        prompts.offerGotAttention()
        if let window { presents(window) }
    }

    /// A download Sparkle already fetched, or began installing,
    /// resumes past the steps it has done.
    static func installsFrom(_ stage: SPUUserUpdateStage)
        -> UpdateWindowPhase
    {
        switch stage {
        case .downloaded: return .preparing
        case .installing: return .installing
        default: return .downloading(received: 0, expected: nil)
        }
    }

    func closeWindow() {
        window?.close()
        window = nil
    }
}
