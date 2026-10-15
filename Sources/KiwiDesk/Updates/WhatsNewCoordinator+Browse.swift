import Foundation

/// Home's "What's new" (#2308): the notes of any listed release,
/// opening on the running one. It answers nothing — the owed notes
/// keep their own window and their Done.
extension WhatsNewCoordinator {
    /// The footer's door. Owed notes open as owed; an update offer
    /// on screen comes forward instead, since it carries the notes
    /// worth reading; otherwise the cached feed opens at once and
    /// the read refreshes it, or the window waits on that read.
    func browse() {
        if waiting != nil { return show() }
        if updateOfferOpen() { return frontsUpdateOffer() }
        if let browsing { return front(browsing) }
        let cached = WhatsNewReleases(
            items: record.cachedFeed,
            current: current
        )
        if let cached { openBrowser(cached) }
        browseFetch?.cancel()
        browseFetch = Task { [weak self] in
            await self?.refreshForBrowse(opens: cached == nil)
        }
    }

    /// Reads the feed into the cache; opens the window from it
    /// when nothing was cached, and with no notes at all offline.
    private func refreshForBrowse(opens: Bool) async {
        guard let url = feedURL(), let items = await fetch(url) else {
            if opens, !Task.isCancelled { openBrowser(nil) }
            return
        }
        record.cacheFeed(items)
        guard opens, !Task.isCancelled else { return }
        openBrowser(WhatsNewReleases(items: items, current: current))
    }

    private func openBrowser(_ releases: WhatsNewReleases?) {
        guard browsing == nil else { return }
        let opening = releases?.opening(owed: false)
        let controller = WhatsNewWindowController(
            offer: opening.flatMap { releases?.offer(for: $0) }
                ?? UpdateOffer.unread(build: current, host: host),
            narration: nil,
            next: nil,
            releases: releases,
            opening: opening,
            showMe: { [weak self] entry in
                guard let self, let browsing = self.browsing else { return }
                self.handOff(entry, from: browsing)
            }
        ) { [weak self] in
            self?.endsTrail()
            self?.browsing = nil
        }
        browsing = controller
        front(controller)
    }
}
