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
        if let window, window.session.retry == .checking,
            window.offer.build == item.versionString
        {
            return window.session.refound(reply: reply)
        }
        let window = makeOffer(for: item, stage: stage, reply: reply)
        let shows = prompts.offerArrived(userInitiated: userInitiated)
        replace(with: .offer(window), presenting: shows)
        if shows { prompts.offerGotAttention() }
        fetchOfferedNext(into: window.session)
    }

    func makeOffer(
        for item: SUAppcastItem,
        stage: SPUUserUpdateStage,
        reply: @escaping (SPUUserUpdateChoice) -> Void
    ) -> UpdateWindowController {
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
        let relaunch = Self.relaunch(
            installing: item,
            loaded: loadedItems,
            host: Bundle.main
        )
        session.onInstall = { [record = seenRecord] in
            record?.markSeen(item.versionString)
        }
        session.onInstalling = { [weak self, record = seenRecord] in
            var carried = relaunch
            carried.next = self?.offeredNext
            record?.markRelaunch(carried)
        }
        return window
    }

    /// "Next on my list" for the offer's tab and the relaunch.
    func fetchOfferedNext(into session: UpdateSession) {
        guard let fetchNext else { return }
        nextFetch = Task { [weak self] in
            let next = await fetchNext()
            guard !Task.isCancelled else { return }
            self?.offeredNext = next
            session.next = next?.current(at: Date())
        }
    }

    /// Shows the offer: it got the user's attention.
    func presentWindow() {
        prompts.offerGotAttention()
        if let window { presents(.offer(window)) }
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

    /// Closes the offer, and only the offer.
    func closeWindow() {
        if window != nil { replace(with: nil) }
    }

    /// What the relaunch narrates (#1667): the items the window
    /// merged, so "What's new" opens without waiting on the feed.
    static func relaunch(
        installing item: SUAppcastItem,
        loaded: [SUAppcastItem],
        host: Bundle
    ) -> WhatsNewRecord.Relaunch {
        WhatsNewRecord.Relaunch(
            version: item.versionString,
            since: host.object(forInfoDictionaryKey: "CFBundleVersion")
                as? String ?? "",
            items: (loaded + [item]).map {
                WhatsNewFeed.Item(
                    version: $0.versionString,
                    shown: $0.displayVersionString,
                    released: $0.date,
                    notes: $0.propertiesDictionary[ReleaseNotes.element]
                        as? String
                )
            }
        )
    }
}
