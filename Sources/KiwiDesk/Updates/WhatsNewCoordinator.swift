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

    init(record: WhatsNewRecord = WhatsNewRecord(), host: Bundle = .main) {
        self.record = record
        self.host = host
    }

    private var current: String {
        host.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? ""
    }

    /// Run once per launch. `userStarted` false is a login launch.
    func launched(userStarted: Bool, existingUser: Bool) async {
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
        guard let url = WhatsNewFeed.url(host: host),
            let items = await fetch(url)
        else { return }  // Offline: still owed next launch.
        guard
            let offer = UpdateOffer.whatsNew(
                items: items,
                since: due.since,
                current: current
            )
        else {
            // This version carries no notes the window can read.
            record.markAnswered(current)
            return
        }
        waiting = offer
        if userStarted { show() }
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
