import Foundation
import Sparkle

/// The releases "What's new" can show (#2308): every feed item up
/// to the running version whose structured notes read — so the
/// untyped 1.x releases never list — newest first, plus the
/// merged range of an update whose skipped notes are owed.
struct WhatsNewReleases {
    enum Option: Hashable {
        /// Everything after the version the update replaced.
        case since(String)
        case release(String)
    }

    /// Readable items, newest first.
    let items: [WhatsNewFeed.Item]
    /// The feed as read, unreadable items included: the merged
    /// range is the owed digest's own, which links each skipped
    /// release whose notes do not read.
    let feed: [WhatsNewFeed.Item]
    /// The running `CFBundleVersion`.
    let current: String
    /// The start of the owed range; nil when the range holds one
    /// release only.
    let since: String?

    /// Nil when the running version's own notes do not read.
    init?(
        items: [WhatsNewFeed.Item],
        current: String,
        since: String? = nil,
        compare: (String, String) -> ComparisonResult = Self.compare
    ) {
        var seen = Set<String>()
        let readable =
            items
            .filter { ReleaseNotes.decode($0.notes) != nil }
            .filter { compare($0.version, current) != .orderedDescending }
            .filter { seen.insert($0.version).inserted }
            .sorted { compare($0.version, $1.version) == .orderedDescending }
        guard readable.first?.version == current else { return nil }
        self.items = readable
        self.feed = items
        self.current = current
        let spanned = since.map { start in
            Set(
                items.filter {
                    compare($0.version, start) == .orderedDescending
                        && compare($0.version, current) != .orderedDescending
                }.map(\.version)
            ).count
        }
        self.since = (spanned ?? 0) > 1 ? since : nil
    }

    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        SUStandardVersionComparator.default.compareVersion(a, toVersion: b)
    }

    /// The merged range first, then every release, newest first.
    var options: [Option] {
        (since.map { [.since($0)] } ?? []) + items.map { .release($0.version) }
    }

    /// The owed range when the window opened for owed notes,
    /// otherwise the running version (#2308 ruling).
    func opening(owed: Bool) -> Option {
        if owed, let since { return .since(since) }
        return .release(current)
    }

    /// The notes an option shows: the merged range through the
    /// digest the owed notes take, or one release alone, which
    /// carries no version tags. Every listed option resolves.
    func offer(for option: Option) -> UpdateOffer? {
        switch option {
        case .since(let start):
            return UpdateOffer.whatsNew(
                items: feed,
                since: start,
                current: current
            )
        case .release(let version):
            guard let item = item(version) else { return nil }
            return UpdateOffer.whatsNew(
                items: [item],
                since: nil,
                current: version
            )
        }
    }

    /// The item a version names, for its shown string and date.
    func item(_ version: String) -> WhatsNewFeed.Item? {
        items.first { $0.version == version }
    }
}

/// The release menu a What's new window carries: the list and its
/// first pick, one value so neither travels without the other.
struct WhatsNewMenu {
    let releases: WhatsNewReleases
    let opening: WhatsNewReleases.Option
    /// The notes the window opens on.
    let offer: UpdateOffer

    /// Nil when `releases` is, or when the opening resolves no
    /// notes — the window then draws no menu.
    init?(_ releases: WhatsNewReleases?, owed: Bool) {
        guard let releases else { return nil }
        let opening = releases.opening(owed: owed)
        guard let offer = releases.offer(for: opening) else { return nil }
        self.releases = releases
        self.opening = opening
        self.offer = offer
    }
}
