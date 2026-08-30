import Foundation

/// Saved KiwiDesk configuration for monitor setups (#36).
public struct Profile: Codable, Sendable, Equatable {
    /// Format version of profile schema (#902, #1020). Format 0 = unversioned.
    public static let currentFormat = 2

    public var format: Int
    public var name: String
    /// Monitor combinations this profile covers (uniform screen count).
    public var monitorSets: [MonitorSet]
    /// Spaces assigned to Main role on current main display.
    public var mainSpaces: [SpaceID]
    /// Default profile for this screen count.
    public var isDefault: Bool
    /// Marks starter setup baseline (#466, #485).
    public var isStarterSetup: Bool
    /// Authoritative display order of spaces for this profile (#75).
    public var spaces: [SpaceID]
    /// Designated rehome target when spaces are missing (#68).
    public var fallbackSpace: SpaceID?
    /// Layout mode per space.
    public var spaceModes: [SpaceID: LayoutMode]
    public var settings: TilingSettings
    public var savedAt: Date
    /// Sparse keybinding overrides (#55).
    public var layers: KeyLayerOverride?
    /// Sparse app-to-space rule overrides (#109).
    public var appRules: AppRuleOverride?
    /// Sparse additions/removals over global `float_rules`.
    public var floatRules: RuleListOverride?
    /// Sparse additions/removals over global `ignore_rules`.
    public var ignoreRules: RuleListOverride?

    /// Number of monitors covered by profile sets.
    public var monitorCount: Int {
        monitorSets.first?.monitors.count ?? 0
    }

    /// All spaces declared across ordered list, modes, Main, or pins.
    public var declaredSpaces: Set<SpaceID> {
        var all = Set(spaces)
        all.formUnion(spaceModes.keys)
        all.formUnion(mainSpaces)
        for set in monitorSets {
            all.formUnion(set.spaceMonitorMap.keys)
        }
        return all
    }

    /// Authoritative display order with unlisted declared spaces appended.
    public var orderedSpaces: [SpaceID] {
        if spaces.isEmpty {
            return SpaceID.numericLexicalSorted(
                Array(declaredSpaces)
            )
        }
        let stored = Set(spaces)
        let extra = declaredSpaces.subtracting(stored)
        return spaces
            + SpaceID.numericLexicalSorted(Array(extra))
    }

    enum CodingKeys: String, CodingKey {
        case format
        case name
        case monitorSets = "monitor_sets"
        case mainSpaces = "main_spaces"
        case isDefault = "default"
        case isStarterSetup = "starter_setup"
        case spaces
        case fallbackSpace = "fallback_space"
        case spaceModes = "space_modes"
        case settings
        case savedAt = "saved_at"
        case layers
        case appRules = "app_rules"
        case floatRules = "float_rules"
        case ignoreRules = "ignore_rules"
    }

    public init(
        format: Int = Profile.currentFormat,
        name: String,
        monitorSets: [MonitorSet],
        mainSpaces: [SpaceID] = [],
        isDefault: Bool = false,
        isStarterSetup: Bool = false,
        spaces: [SpaceID] = [],
        fallbackSpace: SpaceID? = nil,
        spaceModes: [SpaceID: LayoutMode],
        settings: TilingSettings,
        savedAt: Date = .now,
        layers: KeyLayerOverride? = nil,
        appRules: AppRuleOverride? = nil,
        floatRules: RuleListOverride? = nil,
        ignoreRules: RuleListOverride? = nil
    ) {
        self.format = format
        self.name = name
        self.monitorSets = Self.sanitized(monitorSets)
        self.mainSpaces = mainSpaces.sorted { $0.raw < $1.raw }
        self.isDefault = isDefault
        self.isStarterSetup = isStarterSetup
        self.spaces = SpaceID.deduplicated(spaces)
        self.fallbackSpace = fallbackSpace
        self.spaceModes = spaceModes
        self.settings = settings
        self.savedAt = savedAt
        self.layers = layers
        self.appRules = appRules
        self.floatRules = floatRules
        self.ignoreRules = ignoreRules
    }

    /// Lenient where safe (missing flags default), strict where
    /// the profile would be meaningless: zero valid monitor sets
    /// is a decoding error (#31).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let decodedFormat =
            try container.decodeIfPresent(
                Int.self,
                forKey: .format
            ) ?? 0
        guard decodedFormat <= Self.currentFormat else {
            throw DecodingError.dataCorruptedError(
                forKey: .format,
                in: container,
                debugDescription:
                    "profile format \(decodedFormat) is newer "
                    + "than supported \(Self.currentFormat)"
            )
        }
        format = Self.currentFormat
        name = try container.decode(String.self, forKey: .name)
        monitorSets = Self.sanitized(
            try container.decode(
                [MonitorSet].self,
                forKey: .monitorSets
            )
        )
        guard !monitorSets.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .monitorSets,
                in: container,
                debugDescription:
                    "profile has no valid monitor set"
            )
        }
        mainSpaces =
            (try container.decodeIfPresent(
                [SpaceID].self,
                forKey: .mainSpaces
            ) ?? []).sorted { $0.raw < $1.raw }
        isDefault =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .isDefault
            ) ?? false
        // Lenient: absent on every profile authored before #485
        // (and on user-authored copies), decoding to `false`.
        isStarterSetup =
            try container.decodeIfPresent(
                Bool.self,
                forKey: .isStarterSetup
            ) ?? false
        // Lenient: missing key on legacy profiles → empty,
        // which `orderedSpaces` converts to the derived order.
        spaces = SpaceID.deduplicated(
            try container.decodeIfPresent(
                [SpaceID].self,
                forKey: .spaces
            ) ?? []
        )
        // Lenient: absent on pre-#68 profiles; a dangling
        // reference is tolerated here and ignored at use.
        fallbackSpace = try container.decodeIfPresent(
            SpaceID.self,
            forKey: .fallbackSpace
        )
        spaceModes = try container.decode(
            [SpaceID: LayoutMode].self,
            forKey: .spaceModes
        )
        settings = try container.decode(
            TilingSettings.self,
            forKey: .settings
        )
        savedAt = try container.decode(
            Date.self,
            forKey: .savedAt
        )
        layers = try container.decodeIfPresent(
            KeyLayerOverride.self,
            forKey: .layers
        )
        appRules = try container.decodeIfPresent(
            AppRuleOverride.self,
            forKey: .appRules
        )
        floatRules = try container.decodeIfPresent(
            RuleListOverride.self,
            forKey: .floatRules
        )
        ignoreRules = try container.decodeIfPresent(
            RuleListOverride.self,
            forKey: .ignoreRules
        )
    }

    /// All entries must share one `monitors` length — the first
    /// entry's length is canonical, mismatched entries dropped.
    private static func sanitized(
        _ sets: [MonitorSet]
    ) -> [MonitorSet] {
        guard let canonical = sets.first?.monitors.count else {
            return []
        }
        return sets.filter {
            $0.monitors.count == canonical
        }
    }

    /// The stored set covering `fingerprints` (compared as
    /// sorted arrays, not sets), if any.
    public func set(
        matching fingerprints: [String]
    ) -> MonitorSet? {
        let wanted = fingerprints.sorted()
        return monitorSets.first { $0.monitors == wanted }
    }

    /// Adds or replaces the set covering the same monitors.
    /// Rejects (returns false) a set of a different length —
    /// a profile covers exactly one screen count.
    @discardableResult
    public mutating func upsert(
        _ set: MonitorSet
    ) -> Bool {
        guard
            monitorSets.isEmpty
                || set.monitors.count == monitorCount
        else { return false }
        if let index = monitorSets.firstIndex(where: {
            $0.monitors == set.monitors
        }) {
            monitorSets[index] = set
        } else {
            monitorSets.append(set)
        }
        return true
    }
}
