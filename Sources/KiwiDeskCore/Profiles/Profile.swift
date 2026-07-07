import Foundation

/// One concrete monitor combination a profile covers, together
/// with the space→monitor pins valid for that arrangement (#36).
///
/// `monitors` is stored canonically sorted and compared as a
/// sorted array (a multiset — two identical monitors must not
/// collapse the way a `Set` would). The pin map is nested here
/// because a space→fingerprint pair only has meaning inside the
/// set that contains that fingerprint.
public struct MonitorSet: Codable, Sendable, Equatable {
    /// Fingerprints (`Name:WxH`) of the covered monitors,
    /// canonically sorted.
    public private(set) var monitors: [String]
    /// Explicit fingerprint pin per space (sparse; unpinned
    /// spaces resolve via Main and the positional default).
    /// Read-only so the init-time invariant (pins reference
    /// only monitors inside the set) cannot be bypassed.
    public private(set) var spaceMonitorMap: [SpaceID: String]

    private enum CodingKeys: String, CodingKey {
        case monitors
        case spaceMonitorMap = "space_monitor_map"
    }

    public init(
        monitors: [String],
        spaceMonitorMap: [SpaceID: String] = [:]
    ) {
        self.monitors = monitors.sorted()
        // A pin to a monitor outside the set is meaningless;
        // drop it so integrity stays structural.
        self.spaceMonitorMap = spaceMonitorMap.filter {
            monitors.contains($0.value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        let rawMonitors = try container.decode(
            [String].self,
            forKey: .monitors
        )
        let rawMap =
            try container.decodeIfPresent(
                [SpaceID: String].self,
                forKey: .spaceMonitorMap
            ) ?? [:]
        self.init(
            monitors: rawMonitors,
            spaceMonitorMap: rawMap
        )
    }
}

/// A saved KiwiDesk configuration: layout modes per space plus
/// all tiling settings, valid for one or more concrete monitor
/// combinations (#36).
public struct Profile: Codable, Sendable, Equatable {
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
    /// Layout mode per space.
    public var spaceModes: [SpaceID: LayoutMode]
    public var settings: TilingSettings
    public var savedAt: Date

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
        case name
        case monitorSets = "monitor_sets"
        case mainSpaces = "main_spaces"
        case isDefault = "default"
        case spaces
        case spaceModes = "space_modes"
        case settings
        case savedAt = "saved_at"
    }

    public init(
        name: String,
        monitorSets: [MonitorSet],
        mainSpaces: [SpaceID] = [],
        isDefault: Bool = false,
        spaces: [SpaceID] = [],
        spaceModes: [SpaceID: LayoutMode],
        settings: TilingSettings,
        savedAt: Date = .now
    ) {
        self.name = name
        self.monitorSets = Self.sanitized(monitorSets)
        self.mainSpaces = mainSpaces.sorted { $0.raw < $1.raw }
        self.isDefault = isDefault
        self.spaces = SpaceID.deduplicated(spaces)
        self.spaceModes = spaceModes
        self.settings = settings
        self.savedAt = savedAt
    }

    /// Lenient where safe (missing flags default), strict where
    /// the profile would be meaningless: zero valid monitor sets
    /// is a decoding error (#31).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
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
        // Lenient: missing key on legacy profiles → empty,
        // which `orderedSpaces` converts to the derived order.
        spaces = SpaceID.deduplicated(
            try container.decodeIfPresent(
                [SpaceID].self,
                forKey: .spaces
            ) ?? []
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
