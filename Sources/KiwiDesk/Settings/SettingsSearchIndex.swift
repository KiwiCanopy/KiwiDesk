import KiwiDeskCore

/// Static settings search index row: ONE row per census
/// `SettingKey`, never per instance (#678). Everything a match
/// needs is resolved at build time — nothing on the search path
/// touches AX, the session, or the filesystem.
struct SettingsSearchIndexRow: Identifiable, Equatable {
    /// nil for a catalog-only anchor row (a mode tab, a drawer
    /// title) — which controls those are is DERIVED, every catalog
    /// control no census label key claims, never a hand-kept list.
    let key: SettingKey?
    let label: String
    let synonyms: [String]
    let destination: SettingsDestination
    /// Navigation anchor pinned in `SettingsSearchIndexTests` (#277).
    let anchor: SettingsAnchor
    let path: [String]
    let tier: SettingTier
    var id: String {
        key.map(\.id) ?? "control/\(anchor.anchor ?? "none")"
    }
}

@MainActor
enum SettingsSearchIndex {
    /// The membership line — the other tiers have no row on any
    /// screen, so a result for one would land nowhere.
    static let indexedTiers: Set<SettingTier> = [
        .atRest, .showMore, .immediate,
    ]

    /// Locale-keyed search index cache.
    private static var cache = [String: [SettingsSearchIndexRow]]()

    /// The bridge capability, mirrored at model init (#1145):
    /// this filter cannot reach the core, and the fact is
    /// process-constant. A changed value (a test scenario)
    /// drops the cache so the membership moves with it.
    static var canDriveDesktops = false {
        didSet {
            if oldValue != canDriveDesktops { cache = [:] }
        }
    }

    #if DEBUG
        /// Census rows `indexes` refuses on top of its own
        /// predicate — a test's door for refusing a labelled row
        /// whose catalog control is live on this host, since the
        /// real refusals (glass below macOS 26) cannot be reached
        /// from a 26+ runner. Never read by production; the
        /// `#if` is what keeps it so.
        static var refusedOverride: Set<SettingKey> = [] {
            didSet {
                if oldValue != refusedOverride { cache = [:] }
            }
        }
    #endif

    static func rows() -> [SettingsSearchIndexRow] {
        let locale =
            LocalizationManager.shared.effectiveLocale
            ?? "system"
        if let built = cache[locale] { return built }
        let built = build()
        cache[locale] = built
        return built
    }

    /// Tests whether key should be indexed on this machine. The
    /// exclusions are data-driven: `.dynamic` labels have no
    /// static text, glass-gated rows ask the renderer's own
    /// predicate (#390), and a `[space]` key is an INSTANCE —
    /// reachable as a link, never a result (spec item 11).
    static func indexes(_ key: SettingKey) -> Bool {
        #if DEBUG
            if refusedOverride.contains(key) { return false }
        #endif
        let placement = key.placement
        guard placement.area != nil,
            indexedTiers.contains(placement.tier),
            SettingsCensusLabel.label(for: key) != nil,
            !key.id.contains("[space]")
        else { return false }
        let conditions =
            placement.gate?.runtimeConditions ?? []
        let gated = conditions.contains(.liquidGlassUnavailable)
        if gated, !AppBarStyle.glassAvailable { return false }
        // Bridge-gated rows hide with their surface (#1145) — a
        // result for one would land on a row nothing draws.
        if conditions.contains(.desktopBridgeAbsent),
            !canDriveDesktops
        {
            return false
        }
        return true
    }

    /// Builds index in destination order: census settings followed by
    /// catalog-only anchors. A control whose key a census row in
    /// the area carries is that row's — refused with it when
    /// `indexes` refuses the row on this machine (the glass card
    /// below macOS 26) — so `claimed` is read off EVERY labelled census
    /// row of the area, never the indexed subset, or the refusal
    /// resurfaces the control as an extra for a row nothing draws.
    private static func build() -> [SettingsSearchIndexRow] {
        let all = SettingKey.allCases.filter(indexes)
        let ordered =
            SettingsDestination.thisProfile
            + SettingsDestination.wholeApp
        return ordered.flatMap { destination in
            let entries = SettingsCatalog.entries(of: destination)
            let labelled = Set(
                SettingKey.allCases
                    .filter { $0.placement.area == destination.area }
                    .compactMap(labelKey)
            )
            let census = all.filter {
                $0.placement.area == destination.area
            }
            .map { row(for: $0, in: destination, entries) }
            return census
                + extras(
                    in: destination,
                    entries,
                    claimed: Set(
                        entries.filter {
                            $0.control.key.map(labelled.contains)
                                ?? false
                        }
                        .map(\.control.id)
                    )
                )
        }
    }

    private static func labelKey(of key: SettingKey) -> String? {
        guard case .key(let k) = key.text.label else { return nil }
        return k
    }

    /// Catalog declarations whose SURFACE is bridge-gated
    /// (#1125): the census path refuses these at `indexes`, and a
    /// catalog control carries no gate of its own, so the refusal
    /// is spelled here. Data rather than a condition — a third
    /// one joins it with its reason, and its entry is what says
    /// the row would land on a page drawing nothing.
    ///
    /// The two Desktop offers are the ONLY search-reachable name
    /// their families have (the rows are `.dynamic`), so an
    /// unfiltered entry is not a stray hit: it is the door to a
    /// capability, offered on a Mac that has none. A control a
    /// census row NAMES needs no entry here: `build()` claims it
    /// for that row whether or not the row is indexed.
    static var bridgeGatedControls: Set<String> {
        [
            SettingsCatalog.shortcuts.focusDesktops.control.id,
            SettingsCatalog.shortcuts.moveWindowsDesktops.control
                .id,
        ]
    }

    /// Catalog controls no census row landed on, derived from the
    /// two lists so a control is a search row exactly once however
    /// it is declared.
    private static func extras(
        in destination: SettingsDestination,
        _ entries: [SettingsIndexEntry],
        claimed: Set<String>
    ) -> [SettingsSearchIndexRow] {
        entries.filter { !claimed.contains($0.control.id) }
            .filter {
                canDriveDesktops
                    || !bridgeGatedControls.contains(
                        $0.control.id
                    )
            }
            .map { entry in
                var path = [destination.title]
                if let surface =
                    entry.control.surface.displayName,
                    surface != entry.control.text
                {
                    path.append(surface)
                }
                if let parent = entry.parent {
                    path.append(parent.text)
                }
                return SettingsSearchIndexRow(
                    key: nil,
                    label: entry.control.text,
                    synonyms: SettingsSearchSynonyms.catalogTerms(
                        for: entry.control.id
                    ),
                    destination: destination,
                    anchor: SettingsAnchor(
                        destination: destination,
                        surface: entry.control.surface,
                        anchor: entry.control.id
                    ),
                    path: path,
                    tier: .atRest
                )
            }
    }

    private static func row(
        for key: SettingKey,
        in destination: SettingsDestination,
        _ entries: [SettingsIndexEntry]
    ) -> SettingsSearchIndexRow {
        let labelKey = labelKey(of: key)
        let hit = entries.first { $0.control.key == labelKey }
        let surface =
            hit?.control.surface ?? fallbackSurface(for: key)
        var path = [destination.title]
        if let name = surface.displayName {
            path.append(name)
        }
        if let parent = hit?.parent {
            path.append(parent.text)
        }
        return SettingsSearchIndexRow(
            key: key,
            label: SettingsCensusLabel.label(for: key) ?? key.id,
            synonyms: SettingsSearchSynonyms.terms(for: key),
            destination: destination,
            anchor: SettingsAnchor(
                destination: destination,
                surface: surface,
                anchor: hit?.control.id
            ),
            path: path,
            tier: key.placement.tier
        )
    }

    /// Derives layout tab surface for anchorless layout mode settings.
    private static func fallbackSurface(
        for key: SettingKey
    ) -> SettingsSurface {
        guard case .layout = key else { return .main }
        let segments = key.id.split(separator: ".")
        guard segments.count >= 2,
            segments[0] == "settings",
            let mode = LayoutMode(
                rawValue: String(segments[1])
            ),
            LayoutMode.placementTabs.contains(mode)
        else { return .main }
        return .layoutMode(mode)
    }
}

extension SettingsSurface {
    @MainActor var displayName: String? {
        switch self {
        case .main: return nil
        case .layoutMode(let mode): return mode.displayName
        }
    }
}
