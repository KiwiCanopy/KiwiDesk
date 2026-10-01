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
            closeCheckingWindows()
            return window.session.refound(reply: reply)
        }
        // A scheduled offer puts nothing up, so nothing waits on it;
        // dismissing after it would end the session it is pending in.
        if !userInitiated { closeCheckingWindows() }
        openWindow(for: item, stage: stage, reply: reply)
        if prompts.offerArrived(userInitiated: userInitiated) {
            presentWindow()
            closeCheckingWindows()
        }
    }

    /// Takes the checking window down AFTER its answer is key: a
    /// closing key window hands focus back to the window under it,
    /// and Core then reverts the answer's own report as a z-order
    /// echo, sending it behind (#1849).
    func closeCheckingWindows() {
        // Sparkle's own "Checking…" panel; the public door to its
        // private close.
        super.dismissUpdateInstallation()
        closeChecking()
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
        self.window = window
        if let fetchNext {
            nextFetch = Task { [weak self] in
                let next = await fetchNext()
                guard !Task.isCancelled else { return }
                self?.offeredNext = next
                session.next = next?.current(at: Date())
            }
        }
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
        nextFetch?.cancel()
        nextFetch = nil
        offeredNext = nil
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

/// The window's "up to date" answer (#1849).
extension UpdatePromptDriver {
    /// Sparkle's reason is the one the window answers: this build
    /// is the newest, or newer than the feed's newest.
    static func isUpToDate(_ error: any Error) -> Bool {
        let reason =
            (error as NSError).userInfo[SPUNoUpdateFoundReasonKey]
            as? NSNumber
        return reason?.int32Value
            == SPUNoUpdateFoundReason.onLatestVersion.rawValue
            || reason?.int32Value
                == SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue
    }

    func showUpToDate(
        next: NextOnMyList?,
        acknowledgement: @escaping () -> Void
    ) {
        let replaced = upToDate
        let window = UpToDateWindowController(
            offer: UpdateOffer.current(loaded: loadedItems, host: .main),
            next: next
        ) { [weak self] in
            self?.upToDate = nil
            acknowledgement()
        }
        upToDate = window
        presentsUpToDate(window)
        onUpToDate()
        // Only now, behind the answer (`closeCheckingWindows`).
        replaced?.close()
        closeCheckingWindows()
        closeWindow()
    }
}

/// The window's checking state (#1849).
extension UpdatePromptDriver {
    func showChecking(cancellation: @escaping () -> Void) {
        closeChecking()
        let window = UpdateCheckingWindowController(cancel: cancellation)
        checking = window
        presentsChecking(window)
    }

    func closeChecking() {
        checking?.close()
        checking = nil
    }
}
