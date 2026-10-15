import AppKit
import Sparkle

/// "What's new in X" after an update (#1542 ruling ▸ After the
/// update). The one home of whether it waits: a launch the user
/// started opens it, a login launch leaves the status item's mark
/// and a quick-menu row, in #1013's shape — the status item reads
/// `waiting` at render and never keeps a copy.
@MainActor
final class WhatsNewCoordinator {
    let record: WhatsNewRecord
    let host: Bundle
    /// The feed Sparkle resolved; asked at launch, not copied.
    let feedURL: () -> URL?
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
    /// Brings that offer forward — Home's "What's new" yields to
    /// it, since it carries the notes worth reading (#2308).
    var frontsUpdateOffer: () -> Void = {}
    /// Nudged whenever `waiting` changes.
    var onWaitingChanged: () -> Void = {}

    /// The notes owed and not yet opened, with the version they
    /// are for.
    private(set) var waiting: UpdateOffer? {
        didSet { onWaitingChanged() }
    }
    private var window: WhatsNewWindowController?
    /// The release menu beside the owed notes; nil for a 1.x
    /// upgrade, whose range has no recorded start.
    private var releases: WhatsNewReleases?
    /// Home's What's new, which answers nothing (#2308).
    var browsing: WhatsNewWindowController?
    /// The feed read behind Home's What's new; a test awaits it.
    var browseFetch: Task<Void, Never>?
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

    var current: String {
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

    /// Opens the window: at a user-started launch, or from the
    /// quick menu's row.
    /// The one door that puts What's new in front — so it is
    /// where a trail back to it ends (#2038).
    func show() {
        guard let offer = waiting else { return }
        let opening = releases?.opening(owed: true)
        let window =
            self.window
            ?? WhatsNewWindowController(
                offer: opening.flatMap { releases?.offer(for: $0) }
                    ?? offer,
                narration: narration,
                next: next?.current(at: now()),
                releases: releases,
                opening: opening,
                showMe: { [weak self] in self?.showMe($0) }
            ) { [weak self] in
                self?.answered()
            }
        self.window = window
        front(window)
    }

    /// Puts a What's new window in front, ending any trail back
    /// to it (#2038).
    func front(_ controller: WhatsNewWindowController) {
        endsTrail()
        presents(controller)
    }

    /// "Show me" on the owed notes.
    func showMe(_ entry: UpdateNotesDigest.SpotlightEntry) {
        guard let window else { return }
        handOff(entry, from: window)
    }

    /// "Show me" (#2038 ruling ▸ handoff): What's new hides
    /// unanswered and Settings lands on the row, carrying the way
    /// back to the window it came from. A row this build cannot
    /// land on draws no link, so the guard is a net.
    func handOff(
        _ entry: UpdateNotesDigest.SpotlightEntry,
        from controller: WhatsNewWindowController
    ) {
        guard
            let trail = WhatsNewTrail(
                spotlight: controller.shown.digest?.spotlight ?? [],
                picked: entry,
                landing: SpotlightLanding.anchor(for:),
                back: { [weak self, weak controller] in
                    if let controller { self?.front(controller) }
                },
                dismiss: { [weak controller] in controller?.finish() },
                settingsClosed: { [weak self, weak controller] in
                    if let controller { self?.settingsClosed(controller) }
                }
            )
        else { return }
        controller.hide()
        showsInSettings(trail)
    }

    /// Settings closed on the trail: What's new comes back, unless
    /// an update offer is in front — it then waits, hidden, for
    /// the quick menu's row. A no-op unless a "Show me" hid it.
    private func settingsClosed(_ controller: WhatsNewWindowController) {
        guard controller.hidden, !updateOfferOpen() else { return }
        front(controller)
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
