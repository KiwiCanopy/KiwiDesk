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
    public struct Entry: Hashable, Sendable, Codable {
        public let profile: String
        /// The setup's screens as sorted fingerprints, as a
        /// `MonitorSet` keeps them; nil is ALL screen setups —
        /// what every entry written before the scope means.
        public let setup: [String]?

        public init(profile: String, setup: [String]? = nil) {
            self.profile = profile
            self.setup = Self.canonical(setup)
        }

        /// A setup in its canonical order; nil or empty is all
        /// screen setups.
        static func canonical(_ setup: [String]?) -> [String]? {
            guard let setup, !setup.isEmpty else { return nil }
            return setup.sorted()
        }

        /// Stored as a bare name when scoped to all setups — the
        /// shape every record had before #1609 — and as an object
        /// naming its setup otherwise.
        public init(from decoder: Decoder) throws {
            if let name = try? decoder.singleValueContainer()
                .decode(String.self)
            {
                self.init(profile: name)
                return
            }
            let container = try decoder.container(
                keyedBy: CodingKeys.self
            )
            let setup = try container.decode(
                [String].self,
                forKey: .setup
            )
            guard !setup.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .setup,
                    in: container,
                    debugDescription: "a scoped entry names no screens"
                )
            }
            self.init(
                profile: try container.decode(
                    String.self,
                    forKey: .profile
                ),
                setup: setup
            )
        }

        public func encode(to encoder: Encoder) throws {
            guard let setup else {
                var single = encoder.singleValueContainer()
                try single.encode(profile)
                return
            }
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(profile, forKey: .profile)
            try container.encode(setup, forKey: .setup)
        }

        private enum CodingKeys: String, CodingKey {
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

    /// Entries for all screen setups, one per name.
    public init(
        profiles: [String],
        desktop: Int,
        screen: String? = nil
    ) {
        self.init(
            entries: profiles.map { Entry(profile: $0) },
            desktop: desktop,
            screen: screen
        )
    }

    /// One bound profile — the shape every binding had before
    /// #1436, and the one a single-count user still writes.
    public init(profile: String, desktop: Int, screen: String? = nil) {
        self.init(profiles: [profile], desktop: desktop, screen: screen)
    }

    /// Every bound name once, in binding order.
    public var profiles: [String] {
        var seen = Set<String>()
        return entries.map(\.profile).filter { seen.insert($0).inserted }
    }

    /// Files `name` on this Desktop, scoped to `setup` (nil: all
    /// screen setups): every OVERLAPPING entry goes — saved for
    /// the same screen count AND scoped alike — and the others
    /// stay (#1436, #1609). `countOf` reads a profile's count —
    /// nil for one not saved yet, which is a class of its own:
    /// two unsaved names cannot be told apart, so the newer
    /// replaces the older, and each is judged once its file
    /// exists. An entry already filed keeps its place and still
    /// evicts an overlapping sibling, since a profile re-saved at
    /// another count can put two on one.
    public mutating func bind(
        _ name: String,
        setup: [String]? = nil,
        countOf: (String) -> Int?
    ) {
        let entry = Entry(profile: name, setup: setup)
        let count = countOf(name)
        entries.removeAll {
            $0 != entry && $0.setup == entry.setup
                && countOf($0.profile) == count
        }
        if !entries.contains(entry) { entries.append(entry) }
    }

    /// Drops every entry naming `name`; true when the record is
    /// now empty.
    @discardableResult
    public mutating func unbind(_ name: String) -> Bool {
        entries.removeAll { $0.profile == name }
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
        countOf: (String) -> Int?
    ) -> Bool {
        let scope = Entry.canonical(setup)
        entries.removeAll {
            $0.setup == scope && countOf($0.profile) == count
        }
        return entries.isEmpty
    }

    /// A profile rename, followed into every entry in place.
    public mutating func rename(_ old: String, to new: String) {
        entries = entries.map {
            $0.profile == old ? Entry(profile: new, setup: $0.setup) : $0
        }
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
        preferring live: String?
    ) -> [Entry] {
        let here = Entry.canonical(fingerprints)
        func tier(_ scope: [String]?) -> [Entry] {
            let listed = entries.filter { $0.setup == scope }
            return listed.filter { $0.profile == live }
                + listed.filter { $0.profile != live }
        }
        return (here.map(tier) ?? []) + tier(nil)
    }

    private enum CodingKeys: String, CodingKey {
        case entries = "profiles"
        case desktop
        case screen
    }
}
