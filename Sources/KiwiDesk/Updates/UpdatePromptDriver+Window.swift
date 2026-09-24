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
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        if let window, window.session.retry == .checking {
            return window.session.refound(reply: reply)
        }
        openWindow(for: item, reply: reply)
        // A scheduled offer never takes the screen (#1013): the
        // status item carries the mark until the user asks.
        if userInitiated {
            presentWindow()
        } else {
            prompts.updatePending = true
        }
    }

    func openWindow(
        for item: SUAppcastItem,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) {
        closeWindow()
        let session = UpdateSession(reply: reply)
        let window = UpdateWindowController(
            offer: offer(for: item),
            session: session
        )
        // Sparkle is mid-teardown when the dismiss that starts
        // Try Again's check arrives.
        session.startCheck = { [weak self] in
            DispatchQueue.main.async { self?.startCheck() }
        }
        session.hide = { [weak window] in window?.hide() }
        session.end = { [weak self] in self?.closeWindow() }
        self.window = window
    }

    /// Shows the window: the offer got the user's attention.
    func presentWindow() {
        prompts.updatePending = false
        if let window { presents(window) }
    }

    func closeWindow() {
        window?.close()
        window = nil
    }

    /// The offer and its merged notes, read off every item of the
    /// appcast Sparkle last loaded. Versions compare as Sparkle
    /// compares them: `sparkle:version` against `CFBundleVersion`.
    private func offer(for item: SUAppcastItem) -> UpdateOffer {
        let host = Bundle.main
        let installed =
            host.object(forInfoDictionaryKey: "CFBundleVersion")
            as? String ?? ""
        let shown =
            host.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? installed
        let comparator = SUStandardVersionComparator.default
        let sources = (loadedItems + [item]).map {
            UpdateNotesDigest.Source(
                version: $0.versionString,
                notes: $0.propertiesDictionary[ReleaseNotes.element]
                    as? String
            )
        }
        return UpdateOffer(
            version: item.displayVersionString,
            installed: shown,
            released: item.date,
            digest: UpdateNotesDigest.make(
                sources: sources,
                installed: installed,
                offered: item.versionString,
                compare: comparator.compareVersion(_:toVersion:)
            )
        )
    }
}
