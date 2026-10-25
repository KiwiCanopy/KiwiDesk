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
    /// stamp says why — 8 since the bars' shared fields moved to
    /// `kiwishelf` (#1517), 9 since the drag markers' and sticky
    /// mark's Liquid Glass leaves are filled (#1620/#1621), 10
    /// since `float_nudge` retired for `float_placement` (#1674),
    /// 11 since each bar took its edge back from `kiwishelf`
    /// (#1731), 12 since `space_bar.glyph_cap` became
    /// `glyph_span` (#1528), 13 since a profile states which look
    /// it wears and one from before is stamped `own` (#1752), 14
    /// since `app_bar.content` retired (#1528), 15 since a layer
    /// override holds one chord per navigation action (#1797), 16
    /// since the Space switch plates' Liquid Glass leaf was filled
    /// (#1956; the step retired with the slide, #2228), 17 since a
    /// stored app shortcut calls `focus_or_spawn` (#1511), 18 since
    /// a layer override may leave a shared layer out whole (#2022)
    /// — no step, as for 7 — 19 since a stored
    /// `on_space_change: false` was turned on once (#1931; retired
    /// with the slide, #2228), 20 for #2143's step withdrawn by
    /// #2228 (kept so a development build's file loads), 21 since
    /// a stored `show_*` call opens `kiwihub.show` (#2265), 22 since
    /// the layouts side became View (#2309), 23 since a profile
    /// carries a stable `id` (#2324), 24 since a bar's on/off
    /// switch became `visibility: hidden` (#761).
    /// 25 since the minimum window
    /// size is one width × height per layout (#2237; 24 is #761's,
    /// a parallel branch, so a file either stamped crosses here),
    /// 26 so a file a build without #761 stamped 25 crosses #761's
    /// step too, which reads content and so runs twice harmlessly,
    /// 27 since a Go to Desktop row on `✦` + digit takes `✦⌥` +
    /// digit (#2460), 28 since the shelf glide is its expand
    /// (`animations.*_expand*`, owner ruling 2026-10-21), 29 since
    /// `overflow_style` retired (#2235), 30 since the per-layout
    /// `wrap_focus` switches retired for `focus_wrap` (#2493), 31
    /// since the seeded pin row on ⌃⌥P runs Pocket (#2446).
    /// The bump is what RUNS a step: `needsMigration`
    /// short-circuits on it, so a step reaching this shape owes one
    /// whatever it rewrites — a retired key decodes to the default
    /// and an absent leaf to the NEW default, silently, without it.
    public static let currentFormat = 31

    public var format: Int
    /// Stable across renames (#2324); `ProfileManager.write` keeps
    /// the one on disk and mints a fresh one for a taken id.
    public var id: ProfileID
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
    /// Sparse scroll-gesture overrides (#1656).
    public var scrollGesture: ScrollGestureOverride?
    /// Sparse Space history override (#1655); nil follows the base.
    public var spaceHistory: SpaceHistoryKind?
    /// Sparse layout-cycle override (#453); nil follows the base.
    public var modeCycle: [LayoutMode]?
    /// Sparse focus-wrap override (#2493); nil follows the base.
    public var focusWrap: FocusWrap?
    /// Sparse override of `float_automatically` (#2173); nil
    /// follows the base.
    public var floatAutomatically: Bool?
    /// Sparse additions/removals over global `tile_rules` (#2173).
    public var tileRules: RuleListOverride?
    /// Which look this profile wears (#1752): nil is the shared
    /// look in `gui.json`, `.own` the copy in `settings`.
    public var look: LookReference?
    /// Lenses this profile leaves out (#2103 ruling 9), keyed by
    /// `VisionLens.reachKey`, `false` where left out; nil and a
    /// lens it does not name reach it.
    public var lensReach: [String: Bool]?

    public init(
        format: Int = Profile.currentFormat,
        id: ProfileID = .fresh(),
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
        ignoreRules: RuleListOverride? = nil,
        scrollGesture: ScrollGestureOverride? = nil,
        spaceHistory: SpaceHistoryKind? = nil,
        modeCycle: [LayoutMode]? = nil,
        focusWrap: FocusWrap? = nil,
        floatAutomatically: Bool? = nil,
        tileRules: RuleListOverride? = nil,
        look: LookReference? = nil,
        lensReach: [String: Bool]? = nil
    ) {
        self.format = format
        self.id = id
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
        self.scrollGesture = scrollGesture
        self.spaceHistory = spaceHistory
        self.modeCycle = modeCycle
        self.focusWrap = focusWrap
        self.floatAutomatically = floatAutomatically
        self.tileRules = tileRules
        self.look = look
        self.lensReach = lensReach
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
        id = try container.decode(ProfileID.self, forKey: .id)
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
        scrollGesture = try container.decodeIfPresent(
            ScrollGestureOverride.self,
            forKey: .scrollGesture
        )
        spaceHistory = try container.decodeIfPresent(
            SpaceHistoryKind.self,
            forKey: .spaceHistory
        )
        modeCycle = try ModeCycle.decodedIfPresent(
            container,
            forKey: .modeCycle
        )
        focusWrap = try container.decodeIfPresent(
            FocusWrap.self,
            forKey: .focusWrap
        )
        floatAutomatically = try container.decodeIfPresent(
            Bool.self,
            forKey: .floatAutomatically
        )
        tileRules = try container.decodeIfPresent(
            RuleListOverride.self,
            forKey: .tileRules
        )
        look = try container.decodeIfPresent(
            LookReference.self,
            forKey: .look
        )
        lensReach = try container.decodeIfPresent(
            [String: Bool].self,
            forKey: .lensReach
        )
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
