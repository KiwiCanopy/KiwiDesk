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
    /// One bound profile and the screen setup it is scoped to
    /// (#1609). An entry's identity is the PAIR: one profile may
    /// be bound for several setups on one Desktop.
    ///
    /// The profile is named by its stable `id` (#2324 ruling 11);
    /// `name` is then a LABEL a row reads while the profile is
    /// away, and nothing resolves the entry through it. An entry
    /// with no id is PENDING — a name bound before any profile
    /// carried it, or written before ids existed — and resolves by
    /// that name until `KiwiCore.promotePendingBindings` gives it
    /// the id of the file it names.
    public struct Entry: Hashable, Sendable, Codable {
        public let id: ProfileID?
        public let name: String
        /// The setup's screens as sorted fingerprints, as a
        /// `MonitorSet` keeps them; nil is ALL screen setups —
        /// what every entry written before the scope means.
        public let setup: [String]?

        public init(
            id: ProfileID? = nil,
            name: String,
            setup: [String]? = nil
        ) {
            self.id = id
            self.name = name
            self.setup = Self.canonical(setup)
        }

        /// What the entry names: its id, else its pending name.
        public enum Key: Hashable, Sendable {
            case id(ProfileID)
            case pending(String)
        }

        public var key: Key { id.map(Key.id) ?? .pending(name) }

        /// The same entry under the label `name`.
        func labelled(_ name: String) -> Entry {
            Entry(id: id, name: name, setup: setup)
        }

        /// Equal by what it names and its scope, never its label,
        /// which may be stale on another Mac.
        public static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.key == rhs.key && lhs.setup == rhs.setup
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(key)
            hasher.combine(setup)
        }

        /// A setup in `MonitorSet`'s canonical order; nil or empty
        /// is all screen setups.
        static func canonical(_ setup: [String]?) -> [String]? {
            guard let setup, !setup.isEmpty else { return nil }
            return MonitorSet(monitors: setup).monitors
        }

        /// A pending entry is stored as before ids: a bare name
        /// when scoped to all setups, `{profile, setup}` otherwise.
        /// An entry with an id is `{id, name, setup?}`.
        public init(from decoder: Decoder) throws {
            if let name = try? decoder.singleValueContainer()
                .decode(String.self)
            {
                self.init(name: name)
                return
            }
            let container = try decoder.container(
                keyedBy: CodingKeys.self
            )
            let setup = try container.decodeIfPresent(
                [String].self,
                forKey: .setup
            )
            if let setup, setup.isEmpty {
                throw DecodingError.dataCorruptedError(
                    forKey: .setup,
                    in: container,
                    debugDescription: "a scoped entry names no screens"
                )
            }
            if let id = try container.decodeIfPresent(
                ProfileID.self,
                forKey: .id
            ) {
                self.init(
                    id: id,
                    name: try container.decode(String.self, forKey: .name),
                    setup: setup
                )
                return
            }
            guard let setup else {
                throw DecodingError.dataCorruptedError(
                    forKey: .setup,
                    in: container,
                    debugDescription: "a pending entry object is scoped"
                )
            }
            self.init(
                name: try container.decode(String.self, forKey: .profile),
                setup: setup
            )
        }

        public func encode(to encoder: Encoder) throws {
            guard let id else {
                guard let setup else {
                    var single = encoder.singleValueContainer()
                    try single.encode(name)
                    return
                }
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(name, forKey: .profile)
                try container.encode(setup, forKey: .setup)
                return
            }
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(setup, forKey: .setup)
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case profile
            case setup
        }
    }

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
