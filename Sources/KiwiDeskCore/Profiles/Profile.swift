import Foundation

/// Saved KiwiDesk configuration for monitor setups (#36).
public struct Profile: Codable, Sendable, Equatable {
    /// Format version of the profile schema (#902); 0 =
    /// unversioned legacy. 2 since the scroll-duration rename
    /// (#1020), 3 since the retired `resize.feedback` drop
    /// (#1255), 4 since the absent Liquid Glass leaves' fill
    /// (#1369), 5 since the track limit counts the overflow
    /// track (#1354), 6 since a dormant profile holds no set
    /// beside its `monitor_count` (#1530), 7 since a shortcut
    /// override may leave a shared combo out (#1393) — no step
    /// for either: an older reader refuses the shape, and the
    /// stamp says why. The bump
    /// is what RUNS a step: `needsMigration`
    /// short-circuits on it, so a step that must reach this
    /// shape owes one whatever it rewrites — a retired key
    /// decodes to the default and an absent leaf to the NEW
    /// default, silently, without it.
    public static let currentFormat = 7

    public var format: Int
    public var name: String
    /// Monitor combinations this profile covers (uniform screen
    /// count). A combination belongs to one profile (#1530), so
    /// it changes only through `upsert` and `release`.
    public private(set) var monitorSets: [MonitorSet]
    /// The screen count of a DORMANT profile — one whose last set
    /// another profile claimed (#1530). Nil while it holds a set.
    private(set) var dormantMonitorCount: Int?
    /// Spaces assigned to Main role on current main display.
    public var mainSpaces: [SpaceID]
    /// Default profile for this screen count.
    public var isDefault: Bool
    /// Marks the starter-setup baseline (#466, #485). Survives
    /// edits (a tweaked mode keeps the identity) but not a "save
    /// as new" — an explicitly named copy is the user's own.
    public var isStarterSetup: Bool
    /// Authoritative display order of this profile's spaces
    /// (#75). Authority split: `gui.json` owns LIVE order across
    /// the session; this owns per-profile order, consulted on
    /// load. They stay in sync because `apply(profile:)` seeds
    /// live order from here and both save paths capture the
    /// resulting live order back.
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
        monitorSets.first?.monitors.count
            ?? dormantMonitorCount ?? 0
    }

    /// Holds no monitor combination: never auto-matched, loadable
    /// by hand, re-claiming a set on its next save or load (#1530).
    public var isDormant: Bool { monitorSets.isEmpty }

    /// Is its screen count's default AND can load as one: a
    /// dormant profile is never a count's fallback (#1530).
    public var isUsableDefault: Bool { isDefault && !isDormant }

    enum CodingKeys: String, CodingKey {
        case format
        case name
        case monitorSets = "monitor_sets"
        case dormantMonitorCount = "monitor_count"
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
        monitorCount: Int? = nil,
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
        self.dormantMonitorCount =
            self.monitorSets.isEmpty ? monitorCount : nil
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
    /// is a decoding error (#31) unless `monitor_count` names the
    /// count a dormant profile keeps (#1530).
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
        let dormantCount = try container.decodeIfPresent(
            Int.self,
            forKey: .dormantMonitorCount
        )
        dormantMonitorCount =
            monitorSets.isEmpty ? dormantCount : nil
        guard !monitorSets.isEmpty || (dormantCount ?? 0) > 0
        else {
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
    /// a profile covers exactly one screen count, a dormant one
    /// included.
    @discardableResult
    public mutating func upsert(
        _ set: MonitorSet
    ) -> Bool {
        guard
            monitorCount == 0
                || set.monitors.count == monitorCount
        else { return false }
        if let index = monitorSets.firstIndex(where: {
            $0.monitors == set.monitors
        }) {
            monitorSets[index] = set
        } else {
            monitorSets.append(set)
        }
        dormantMonitorCount = nil
        return true
    }

    /// Removes the set covering `monitors`, keeping the count so a
    /// profile left with none goes dormant (#1530). False when no
    /// set covers them.
    @discardableResult
    mutating func release(_ monitors: [String]) -> Bool {
        let wanted = monitors.sorted()
        guard
            let index = monitorSets.firstIndex(where: {
                $0.monitors == wanted
            })
        else { return false }
        let count = monitorCount
        monitorSets.remove(at: index)
        if monitorSets.isEmpty { dormantMonitorCount = count }
        return true
    }
}
