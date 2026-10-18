import Foundation

extension DesktopBinding {
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
}
