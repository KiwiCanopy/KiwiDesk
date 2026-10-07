import AppKit
import Sparkle

/// The update window on screen (#1849): at most one — the check,
/// the offer or the up-to-date answer — and replaced only through
/// `UpdatePromptDriver.replace(with:presenting:)`.
@MainActor
enum UpdateWindowSlot {
    case checking(UpdateCheckingWindowController)
    case offer(UpdateWindowController)
    case upToDate(UpToDateWindowController)

    func present() {
        switch self {
        case .checking(let window): window.present()
        case .offer(let window): window.present()
        case .upToDate(let window): window.present()
        }
    }

    func close() {
        switch self {
        case .checking(let window): window.close()
        case .offer(let window): window.close()
        case .upToDate(let window): window.close()
        }
    }

    /// A waiting update offer — the one window a hidden What's new
    /// yields to (#1542 "outranked by a waiting update", #2038).
    var isOffer: Bool {
        if case .offer = self { return true }
        return false
    }

    /// The up-to-date answer, which Home narrates while it is open.
    var isAnswer: Bool {
        if case .upToDate = self { return true }
        return false
    }

    fileprivate var controller: AnyObject {
        switch self {
        case .checking(let window): return window
        case .offer(let window): return window
        case .upToDate(let window): return window
        }
    }
}

/// A not-found answer waiting on its list under the checking
/// window: the fetch, and Sparkle's acknowledgement it holds.
struct PendingUpToDate {
    let fetch: Task<Void, Never>
    let acknowledgement: () -> Void
}

extension UpdatePromptDriver {
    /// The open offer, which the phase overrides route to.
    var window: UpdateWindowController? {
        if case .offer(let window) = current { return window }
        return nil
    }

    var checking: UpdateCheckingWindowController? {
        if case .checking(let window) = current { return window }
        return nil
    }

    var upToDate: UpToDateWindowController? {
        if case .upToDate(let window) = current { return window }
        return nil
    }

    /// The pending answer's fetch; a test awaits it.
    var upToDateFetch: Task<Void, Never>? { pendingUpToDate?.fetch }

    /// The one door between update windows: the new one is put up
    /// and keyed BEFORE the old one goes — a closing key window
    /// hands focus back to the window under it, and Core then
    /// reverts the new one's report as a z-order echo (#1849). The
    /// old slot's work ends with it.
    func replace(with new: UpdateWindowSlot?, presenting: Bool = true) {
        let old = current
        if presenting, let new { presents(new) }
        current = new
        guard let old, old.controller !== new?.controller else { return }
        closes(old)
        if case .offer = old {
            nextFetch?.cancel()
            nextFetch = nil
            offeredNext = nil
        }
    }

    /// Brings the open update window forward. Sparkle asks only
    /// while it shows an update, so the click asks here first.
    @discardableResult
    func focusOpenWindow() -> Bool {
        guard let current else { return false }
        if case .offer = current { prompts.offerGotAttention() }
        presents(current)
        return true
    }

    func showChecking(cancellation: @escaping () -> Void) {
        let window = UpdateCheckingWindowController { [weak self] in
            self?.cancelCheck(cancellation)
        }
        replace(with: .checking(window))
    }

    /// Cancel on the checking window. Once Sparkle has answered
    /// not-found its cancellation does nothing, so a pending answer
    /// ends here and Sparkle is acknowledged once.
    func cancelCheck(_ cancellation: () -> Void) {
        guard let pending = pendingUpToDate else {
            replace(with: nil)
            return cancellation()
        }
        pendingUpToDate = nil
        pending.fetch.cancel()
        replace(with: nil)
        pending.acknowledgement()
    }

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

    /// Fetches the list while the checking window stays up, then
    /// answers.
    func awaitUpToDate(acknowledgement: @escaping () -> Void) {
        pendingUpToDate?.fetch.cancel()
        let fetch = Task { [weak self, fetchNext] in
            let next = await fetchNext?()
            guard !Task.isCancelled else { return }
            self?.showUpToDate(
                next: next?.current(at: Date()),
                acknowledgement: acknowledgement
            )
        }
        pendingUpToDate = PendingUpToDate(
            fetch: fetch,
            acknowledgement: acknowledgement
        )
    }

    func showUpToDate(
        next: NextOnMyList?,
        acknowledgement: @escaping () -> Void
    ) {
        pendingUpToDate = nil
        var shown: UpToDateWindowController?
        let window = UpToDateWindowController(
            offer: UpdateOffer.current(loaded: loadedItems, host: .main),
            next: next
        ) { [weak self] in
            if let self, let shown, self.upToDate === shown {
                self.replace(with: nil)
            }
            acknowledgement()
        }
        shown = window
        replace(with: .upToDate(window))
    }
}
