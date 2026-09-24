import AppKit
import Sparkle

/// "What's new in X" after an update (#1542 ruling ▸ After the
/// update). The one home of whether it waits: a launch the user
/// started opens it, a login launch leaves the status item's mark
/// and a quick-menu row, in #1013's shape — the status item reads
/// `waiting` at render and never keeps a copy.
@MainActor
final class WhatsNewCoordinator {
    private let record: WhatsNewRecord
    private let host: Bundle
    /// The feed Sparkle resolved; asked at launch, not copied.
    private let feedURL: () -> URL?
    /// Fetches the feed; a test hands items in.
    var fetch: (URL) async -> [WhatsNewFeed.Item]? = WhatsNewFeed.fetch
    /// Puts the window on screen; a test records it instead.
    var presents: (WhatsNewWindowController) -> Void = { $0.present() }
    /// Nudged whenever `waiting` changes.
    var onWaitingChanged: () -> Void = {}

    /// The notes owed and not yet opened, with the version they
    /// are for.
    private(set) var waiting: UpdateOffer? {
        didSet { onWaitingChanged() }
    }
    private var window: WhatsNewWindowController?

    init(
        record: WhatsNewRecord,
        host: Bundle,
        feedURL: @escaping () -> URL?
    ) {
        self.record = record
        self.host = host
        self.feedURL = feedURL
    }

    private var current: String {
        host.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? ""
    }

    /// Run once per launch. `opensWindow` false — a login launch,
    /// an unrecognised one, or one a tour owns —
    /// leaves only the mark. `existingUser` is the tour having
    /// reached its end, the proxy for a 1.x install: 1.x recorded
    /// no version, so a user who left the tour early is read as a
    /// fresh install and owed nothing.
    func launched(opensWindow: Bool, existingUser: Bool) async {
        let current = self.current
        guard
            let due = WhatsNewRecord.due(
                current: current,
                lastRun: record.lastRun,
                seen: record.seen,
                existingUser: existingUser,
                compare: SUStandardVersionComparator.default
                    .compareVersion(_:toVersion:)
            )
        else {
            record.markAnswered(current)
            return
        }
        // Offline, or a feed that does not list this version yet
        // (a direct download ahead of the feed): still owed.
        guard let url = feedURL(),
            let items = await fetch(url),
            items.contains(where: { $0.version == current })
        else { return }
        guard
            let offer = UpdateOffer.whatsNew(
                items: items,
                since: due.since,
                current: current
            )
        else {
            // Listed, with no notes the window can read.
            record.markAnswered(current)
            return
        }
        waiting = offer
        if opensWindow { show() }
    }

    /// Opens the window: at a user-started launch, or from the
    /// quick menu's row.
    func show() {
        guard let offer = waiting else { return }
        let window =
            self.window
            ?? WhatsNewWindowController(offer: offer) { [weak self] in
                self?.answered()
            }
        self.window = window
        presents(window)
    }

    private func answered() {
        record.markAnswered(current)
        window = nil
        waiting = nil
    }
}
