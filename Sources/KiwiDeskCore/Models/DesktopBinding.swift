import Foundation

/// What one Desktop→profile binding holds (#1147).
///
/// The binding is KEYED by `DesktopKey`; everything here is what
/// that key cannot carry. `desktop` and `screen` are
/// **projections** of the DESKTOP — the Mission Control number
/// the binding was declared at and the name of the screen it was
/// last seen on (#1438), refreshed from every snapshot that
/// resolves the Desktop, and what a row is labelled with while
/// the Desktop is away. Nothing resolves a binding through
/// either; they sit once on this per-Desktop record, beside its
/// scoped entries (#1436, #1609).
public struct DesktopBinding: Hashable, Sendable, Codable {
    /// What this Desktop selects (#1436, #1609): per screen
    /// count, one entry for all screen setups and one per
    /// specific setup. The count is each profile's own
    /// `monitorCount`, read at the gate and never stored here;
    /// which one loads is `KiwiCore.boundProfile(of:)`'s to
    /// decide against the connected screens. Never empty: a
    /// record with nothing bound is removed rather than kept.
    /// Changes only through the algebra below.
    public private(set) var entries: [Entry]
    /// The Mission Control number last seen for this Desktop.
    public var desktop: Int
    /// The display name this Desktop was last seen on (#1438),
    /// nil until a reading has named it. Additive: a record
    /// written before it decodes to nil, which IS "not yet
    /// named", so no format bump — #1230's `desktop_spaces`
    /// precedent. Encoded only where set.
    public var screen: String?

    public init(
        entries: [Entry],
        desktop: Int,
        screen: String? = nil
    ) {
        self.entries = entries
        self.desktop = desktop
        self.screen = screen
    }

    /// Pending entries for all screen setups, one per name.
    public init(
        profiles: [String],
        desktop: Int,
        screen: String? = nil
    ) {
        self.init(
            entries: profiles.map { Entry(name: $0) },
            desktop: desktop,
            screen: screen
        )
    }

    /// One pending profile — the shape every binding had before
    /// #1436, and the one a single-count user still writes.
    public init(profile: String, desktop: Int, screen: String? = nil) {
        self.init(profiles: [profile], desktop: desktop, screen: screen)
    }

    /// Every entry's label once, in binding order.
    public var names: [String] {
        var seen = Set<String>()
        return entries.map(\.name).filter { seen.insert($0).inserted }
    }

    /// Files `entry` on this Desktop: every OVERLAPPING entry goes
    /// — saved for the same screen count AND scoped alike — and the
    /// others stay (#1436, #1609). `countOf` reads an entry's
    /// profile count — nil for one with no profile yet, which is a
    /// class of its own: two such entries cannot be told apart, so
    /// the newer replaces the older, and each is judged once its
    /// file exists. An entry already filed keeps its place, its
    /// label refreshed, and still evicts an overlapping sibling,
    /// since a profile re-saved at another count can put two on one.
    public mutating func bind(
        _ entry: Entry,
        countOf: (Entry) -> Int?
    ) {
        let count = countOf(entry)
        entries.removeAll {
            $0 != entry && $0.setup == entry.setup
                && countOf($0) == count
        }
        if let at = entries.firstIndex(of: entry) {
            entries[at] = entry
        } else {
            entries.append(entry)
        }
    }

    /// Drops every entry naming `key`; true when the record is now
    /// empty.
    @discardableResult
    public mutating func unbind(_ key: Entry.Key) -> Bool {
        entries.removeAll { $0.key == key }
        return entries.isEmpty
    }

    /// Drops every entry saved for `count` and scoped to `setup`
    /// (nil: all screen setups) — what one bind of that count
    /// and scope would replace; true when the record is now
    /// empty.
    @discardableResult
    public mutating func unbind(
        count: Int,
        setup: [String]? = nil,
        countOf: (Entry) -> Int?
    ) -> Bool {
        let scope = Entry.canonical(setup)
        entries.removeAll {
            $0.setup == scope && countOf($0) == count
        }
        return entries.isEmpty
    }

    /// A profile rename: the label of every entry naming `id`
    /// follows, and a pending entry naming `old` follows by name,
    /// as it would have before ids.
    public mutating func relabel(
        _ id: ProfileID?,
        from old: String,
        to new: String
    ) {
        entries = entries.map { entry in
            if let id, entry.id == id { return entry.labelled(new) }
            if entry.id == nil, entry.name == old {
                return entry.labelled(new)
            }
            return entry
        }
    }

    /// Each pending entry given the id `resolve` finds for its
    /// name, its label kept; true when any changed.
    @discardableResult
    public mutating func promote(
        _ resolve: (String) -> ProfileID?
    ) -> Bool {
        var changed = false
        entries = entries.map { entry in
            guard entry.id == nil, let id = resolve(entry.name) else {
                return entry
            }
            changed = true
            return Entry(id: id, name: entry.name, setup: entry.setup)
        }
        return changed
    }

    /// Each id entry's label set to the name `current` reads for its
    /// id, where it reads one; true when any changed.
    @discardableResult
    public mutating func refreshLabels(
        _ current: (ProfileID) -> String?
    ) -> Bool {
        var changed = false
        entries = entries.map { entry in
            guard let id = entry.id, let name = current(id),
                name != entry.name
            else { return entry }
            changed = true
            return entry.labelled(name)
        }
        return changed
    }

    /// Whether two records store the same thing, labels included —
    /// `==` ignores labels, which a rewrite must still carry.
    public static func sameStored(
        _ lhs: DesktopBinding?,
        _ rhs: DesktopBinding?
    ) -> Bool {
        lhs == rhs && lhs?.entries.map(\.name) == rhs?.entries.map(\.name)
    }

    /// Whether `entry` names the live profile `live`: by id, or a
    /// pending entry by its name.
    public static func names(
        _ entry: Entry,
        _ live: (id: ProfileID, name: String)?
    ) -> Bool {
        guard let live else { return false }
        if let id = entry.id { return id == live.id }
        return entry.name == live.name
    }

    /// The entries that APPLY to the screens `fingerprints` name,
    /// in the ONE rank every reader picks by (#1436, #1609): those
    /// scoped to exactly this setup, then those for all setups,
    /// each tier with `live` first where it is listed and then in
    /// binding order — so the gate's pick, the door's stand-down
    /// and a row's reading cannot name different entries. An
    /// entry scoped to another setup is not among them.
    public func ranked(
        for fingerprints: [String],
        preferring live: (id: ProfileID, name: String)?
    ) -> [Entry] {
        let here = Entry.canonical(fingerprints)
        let scoped = here.map { ranked(scope: $0, preferring: live) }
        return (scoped ?? []) + ranked(scope: nil, preferring: live)
    }

    /// One tier of that rank: the entries scoped to `setup` (nil:
    /// all screen setups), `live` first, then binding order — the
    /// one copy a slot's picker reads too.
    public func ranked(
        scope setup: [String]?,
        preferring live: (id: ProfileID, name: String)?
    ) -> [Entry] {
        let listed = entries.filter { $0.setup == Entry.canonical(setup) }
        return listed.filter { Self.names($0, live) }
            + listed.filter { !Self.names($0, live) }
    }

    private enum CodingKeys: String, CodingKey {
        case entries = "profiles"
        case desktop
        case screen
    }
}
