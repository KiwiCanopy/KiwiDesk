import Foundation

/// A saved KiwiDesk configuration: layout modes per space plus
/// all tiling settings, valid for one or more concrete monitor
/// combinations (#36).
public struct Profile: Codable, Sendable, Equatable {
    /// Format version of the profile schema (#902).
    /// Format 0 = unversioned legacy (v0.9.7 and earlier).
    public static let currentFormat = 1

    public var format: Int
    public var name: String
    /// The monitor combinations this profile covers. All entries
    /// share one length; the profile's screen count.
    public var monitorSets: [MonitorSet]
    /// Spaces assigned to the *Main* role — the current main
    /// display, resolved live. Hardware-agnostic, so stored once
    /// at profile level, not per set.
    public var mainSpaces: [SpaceID]
    /// Marks this profile as its screen count's default (the
    /// dirty-load fallback when no set matches exactly).
    public var isDefault: Bool
    /// Marks this profile as the beginner `Starter` setup seed
    /// (#466/#485). While it is the active baseline, a monitor
    /// change that no stored set covers recomposes the *setup*
    /// at the live display count instead of a workflow Standard,
    /// so the five-per-display shape survives every reconnect.
    /// Survives edits (a tweaked mode keeps the identity) but not
    /// a "save as new" — an explicitly named copy is the user's
    /// own profile. Legacy/other profiles decode to `false`.
    public var isStarterSetup: Bool
    /// Persisted display order of the profile's spaces (#75).
    /// This is the authoritative order for the Spaces list and
    /// for the reconcile rehome fallback on profile switch.
    /// New spaces append; existing profiles without this key
    /// decode to `[]` and fall back to the derived order.
    ///
    /// Authority: `gui.json` owns live display order across the
    /// session; `Profile.spaces` owns per-profile order,
    /// consulted when that profile is loaded. The two stay in
    /// sync because `apply(profile:)` seeds live order from
    /// this list and both save paths (`persistProfile`,
    /// `overwriteProfile`) capture the resulting live order
    /// back here.
    public var spaces: [SpaceID]
    /// The explicitly designated rehome target (#68): windows
    /// from spaces this profile doesn't declare land here when
    /// the profile is loaded. nil (or a dangling reference)
    /// falls back to the stored order's first surviving space
    /// — the pre-#68 rule, so legacy profiles keep behaving.
    public var fallbackSpace: SpaceID?
    /// Layout mode per space.
    public var spaceModes: [SpaceID: LayoutMode]
    public var settings: TilingSettings
    public var savedAt: Date
    /// Per-profile sparse keybinding override (#55). nil
    /// inherits the base modes (gui.json) entirely; present,
    /// it shadows by mode name then combo (O4 soft).
    public var layers: KeyLayerOverride?
    /// Per-profile sparse app→space rule override (#109). nil
    /// inherits the global `app_rules` base entirely;
    /// present, it shadows per app — with a null tombstone to
    /// un-pin an app the base pins.
    public var appRules: AppRuleOverride?
    /// Sparse additions/removals over the global `float_rules`.
    public var floatRules: RuleListOverride?
    /// Hidden sparse additions/removals over global `ignore_rules`.
    public var ignoreRules: RuleListOverride?

    /// Derived from the sets — never stored separately.
    public var monitorCount: Int {
        monitorSets.first?.monitors.count ?? 0
    }

    /// Every space the profile declares — by ordered list, mode,
    /// Main role, or a monitor pin. The one definition of "this
    /// profile's spaces", so an authoritative load prunes to
    /// exactly what the editor shows.
    public var declaredSpaces: Set<SpaceID> {
        var all = Set(spaces)
        all.formUnion(spaceModes.keys)
        all.formUnion(mainSpaces)
        for set in monitorSets {
            all.formUnion(set.spaceMonitorMap.keys)
        }
        return all
    }

    /// Authoritative display order for this profile's spaces.
    ///
    /// Returns `spaces` when non-empty, with any declared space
    /// absent from the list appended (sorted numerically then
    /// lexically) — guards against hand-edited JSON gaps.
    /// Falls back to sorted `declaredSpaces` for legacy profiles
    /// that predate the `spaces` key.
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

    private enum CodingKeys: String, CodingKey {
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
