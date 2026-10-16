import AppKit
import Sparkle

/// "What's new in X" after an update (#1542 ruling ▸ After the
/// update). The one home of whether it waits: a launch the user
/// started opens it, a login launch leaves the status item's mark
/// and a quick-menu row, in #1013's shape — the status item reads
/// `waiting` at render and never keeps a copy. Home's "What's new"
/// opens the same window on any release and answers nothing
/// (#2308); one window is up at a time.
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
    /// Whether a waiting update offer is on screen; it outranks
    /// the notes (#1542), so a hidden What's new is not fronted
    /// over it when Settings closes. The user's own check and its
    /// answer do not hold it back.
    var updateOfferOpen: () -> Bool = { false }
    /// Brings a waiting update offer forward, false when there is
    /// none — Home's "What's new" yields to it, since it outranks
    /// the notes (#1542, #2308).
    var frontsUpdateOffer: () -> Bool = { false }
    /// Nudged whenever `waiting` changes.
    var onWaitingChanged: () -> Void = {}

    /// The notes owed and not yet opened, with the version they
    /// are for.
    private(set) var waiting: UpdateOffer? {
        didSet { onWaitingChanged() }
    }
    /// The one What's new window: the owed notes' or Home's.
    private(set) var window: WhatsNewWindowController?
    /// Whether `window` holds the owed notes, whose Done answers.
    private var windowIsOwed = false
    /// The release menu beside the owed notes; nil for a 1.x
    /// upgrade, whose range has no recorded start.
    private var releases: WhatsNewReleases?
    /// The feed read behind Home's What's new; a test awaits it.
    private(set) var browseFetch: Task<Void, Never>?
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
        record.cacheFeed(relaunch.items)
        self.narration = narration
        next = relaunch.next
        releases = WhatsNewReleases(
            items: relaunch.items,
            current: current,
            since: relaunch.since
        )
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
        guard let url = feedURL(), let items = await fetch(url) else {
            return
        }
        record.cacheFeed(items)
        guard items.contains(where: { $0.version == current }) else {
            return
        }
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
        releases = due.since.flatMap {
            WhatsNewReleases(items: items, current: current, since: $0)
        }
        waiting = offer
        if opensWindow { show() }
    }

    /// Opens the owed notes: at a user-started launch, from the
    /// quick menu's row, or from Home's "What's new" while they
    /// wait — replacing Home's window, so one is up at a time.
    /// The one door that puts the owed notes in front — so it is
    /// where a trail back to them ends (#2038).
    func show() {
        guard let offer = waiting else { return }
        if let window, !windowIsOwed { window.finish() }
        let window =
            self.window
            ?? WhatsNewWindowController(
                offer: offer,
                narration: narration,
                next: next?.current(at: now()),
                menu: WhatsNewMenu(releases, owed: true),
                showMe: { [weak self] in self?.showMe($0) }
            ) { [weak self] in
                self?.answered()
            }
        self.window = window
        windowIsOwed = true
        front(window)
    }

    /// Home's "What's new" (#2308): an update offer on screen comes
    /// forward, owed notes open as owed, an open window comes
    /// forward; otherwise the cached feed opens at once on the
    /// running version and the read refreshes the cache, or the
    /// window waits on that read.
    func browse() {
        if frontsUpdateOffer() { return }
        if waiting != nil { return show() }
        if let window { return front(window) }
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

    /// Reads the feed into the cache; opens the window from it when
    /// nothing was cached — with no notes offline — unless another
    /// window or an offer took the screen during the read.
    private func refreshForBrowse(opens: Bool) async {
        var items: [WhatsNewFeed.Item]?
        if let url = feedURL() { items = await fetch(url) }
        if let items { record.cacheFeed(items) }
        guard opens, !Task.isCancelled, window == nil, waiting == nil,
            !updateOfferOpen()
        else { return }
        openBrowser(
            items.flatMap { WhatsNewReleases(items: $0, current: current) }
        )
    }

    private func openBrowser(_ releases: WhatsNewReleases?) {
        let controller = WhatsNewWindowController(
            offer: UpdateOffer.unread(build: current, host: host),
            narration: nil,
            next: nil,
            menu: WhatsNewMenu(releases, owed: false),
            showMe: { [weak self] in self?.showMe($0) }
        ) { [weak self] in
            self?.browseClosed()
        }
        window = controller
        windowIsOwed = false
        front(controller)
    }

    /// Home's window closed; it answers nothing. A no-op once the
    /// owed notes replaced it.
    private func browseClosed() {
        guard !windowIsOwed else { return }
        endsTrail()
        window = nil
    }

    private func front(_ controller: WhatsNewWindowController) {
        endsTrail()
        presents(controller)
    }

    /// "Show me" (#2038 ruling ▸ handoff): What's new hides
    /// unanswered and Settings lands on the row, carrying the way
    /// back. A row this build cannot land on draws no link, so
    /// the guard is a net.
    func showMe(_ entry: UpdateNotesDigest.SpotlightEntry) {
        guard let window,
            let trail = WhatsNewTrail(
                spotlight: window.shown.digest?.spotlight ?? [],
                picked: entry,
                landing: SpotlightLanding.anchor(for:),
                back: { [weak self, weak window] in
                    if let window { self?.front(window) }
                },
                dismiss: { [weak window] in window?.finish() },
                settingsClosed: { [weak self] in self?.settingsClosed() }
            )
        else { return }
        window.hide()
        showsInSettings(trail)
    }

    /// Settings closed on the trail: What's new comes back, unless
    /// an update offer is in front — it then waits, hidden, for
    /// the quick menu's row. A no-op unless a "Show me" hid it.
    private func settingsClosed() {
        guard let window, window.hidden, !updateOfferOpen() else { return }
        front(window)
    }

    private func answered() {
        endsTrail()
        record.markAnswered(current)
        window = nil
        releases = nil
        narration = nil
        next = nil
        waiting = nil
    }
}
