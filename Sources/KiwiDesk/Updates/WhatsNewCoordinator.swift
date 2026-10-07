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
    /// Fetches "Next on my list" beside the feed (#1813); a test
    /// hands one in.
    var fetchNext: (URL) async -> NextOnMyList? = {
        await NextOnMyList.fetch(besideFeed: $0)
    }
    /// The clock the list's age is judged on; a test pins it.
    var now: () -> Date = Date.init
    /// Puts the window on screen; a test records it instead.
    var presents: (WhatsNewWindowController) -> Void = { $0.present() }
    /// Opens Settings on a spotlight row's control with the way
    /// back (#2038 ruling ▸ handoff); the app sets it once, with
    /// `endsTrail` beside it.
    var showsInSettings: (WhatsNewTrail) -> Void = { _ in }
    /// Takes the trail's banner down without answering it — the
    /// window it leads back to is in front again or answered.
    var endsTrail: () -> Void = {}
    /// Whether an update window holds the screen; a hidden What's
    /// new is not fronted over it when Settings closes.
    var updateWindowOpen: () -> Bool = { false }
    /// Nudged whenever `waiting` changes.
    var onWaitingChanged: () -> Void = {}

    /// The notes owed and not yet opened, with the version they
    /// are for.
    private(set) var waiting: UpdateOffer? {
        didSet { onWaitingChanged() }
    }
    private var window: WhatsNewWindowController?
    /// The boot line a relaunch narrates; nil on any other launch.
    private var narration: BootNarration?
    /// "Next on my list" for the notes waiting, judged at show.
    private var next: NextOnMyList?

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

    /// After an install from the update window (#1667): opens at
    /// once from the notes the install carried, narrating boot,
    /// whatever the launch looks like — Sparkle relaunches it. False
    /// when this launch is no such relaunch; `launched` then runs.
    func relaunched(opensWindow: Bool, narration: BootNarration) -> Bool {
        guard let relaunch = record.takeRelaunch(),
            relaunch.version == current,
            let offer = UpdateOffer.whatsNew(
                items: relaunch.items,
                since: relaunch.since,
                current: current
            )
        else { return false }
        self.narration = narration
        next = relaunch.next
        waiting = offer
        if opensWindow { show() }
        return true
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
        next = await fetchNext(url)
        waiting = offer
        if opensWindow { show() }
    }

    /// Opens the window: at a user-started launch, or from the
    /// quick menu's row.
    /// The one door that puts What's new in front — so it is
    /// where a trail back to it ends (#2038).
    func show() {
        guard let offer = waiting else { return }
        let window =
            self.window
            ?? WhatsNewWindowController(
                offer: offer,
                narration: narration,
                next: next?.current(at: now()),
                showMe: { [weak self] in self?.showMe($0) }
            ) { [weak self] in
                self?.answered()
            }
        self.window = window
        endsTrail()
        presents(window)
    }

    /// "Show me" (#2038 ruling ▸ handoff): What's new hides
    /// unanswered and Settings lands on the row, carrying the way
    /// back. A row this build cannot land on draws no link, so
    /// the guard is a net.
    func showMe(_ entry: UpdateNotesDigest.SpotlightEntry) {
        guard let window,
            let trail = WhatsNewTrail(
                spotlight: window.offer.digest?.spotlight ?? [],
                picked: entry,
                landing: SpotlightLanding.anchor(for:),
                back: { [weak self] in self?.show() },
                dismiss: { [weak self] in self?.window?.finish() },
                settingsClosed: { [weak self] in self?.settingsClosed() }
            )
        else { return }
        window.hide()
        showsInSettings(trail)
    }

    /// Settings closed on the trail: What's new comes back, unless
    /// an update window is in front — it then waits, hidden, for
    /// the quick menu's row.
    private func settingsClosed() {
        guard !updateWindowOpen() else { return }
        show()
    }

    private func answered() {
        endsTrail()
        record.markAnswered(current)
        window = nil
        narration = nil
        next = nil
        waiting = nil
    }
}
