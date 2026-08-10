import KiwiDeskCore

/// The static settings search index (#678 turn 11, spec 11a):
/// ONE row per census `SettingKey`, never per instance — a
/// keybinding family or a per-space override is one setting and
/// one result, so the index is the same fixed list whatever the
/// user's config holds. Built once per locale from the census
/// and matched by synchronous substring scan; everything a
/// match needs (label, synonyms, breadcrumb, anchor) is resolved
/// at build time, so the match path allocates nothing and asks
/// nothing beyond this array.
///
/// Enrichment — the current value, gate state, the mode tag's
/// resolution — deliberately does NOT live here: it is computed
/// per visible row after the result list paints
/// (`SettingsSearchRow`), from the draft in memory. Nothing on
/// the search path touches AX, the session, or the filesystem.
struct SettingsSearchIndexRow: Identifiable, Equatable {
    /// The census setting this row answers for — or nil for a
    /// catalog-only anchor row: a Layout Defaults mode tab, a
    /// drawer title, the Bars switch chips. Those are
    /// NAVIGATION surfaces rather than settings (no value, no
    /// tier of their own), but a search that cannot find
    /// "Monocle" or "Per-edge…" would answer less than the
    /// sidebar-era search did. Which controls they are is
    /// derived — every catalog control no census label key
    /// claims — never a hand-kept list.
    let key: SettingKey?
    /// Localized label, resolved at build through
    /// `SettingsCensusLabel` — the diff rows' label authority,
    /// so search and the draft popover cannot name one row two
    /// ways.
    let label: String
    /// Match-only English terms (`SettingsSearchSynonyms`) —
    /// never displayed, so they stay code data rather than
    /// catalog keys.
    let synonyms: [String]
    let destination: SettingsDestination
    /// Where committing the row lands: the catalog control that
    /// carries the row's label key when one exists (surface +
    /// scroll id + drawer auto-expand come free), else the bare
    /// destination. The #277 catalog covers a fraction of the
    /// census, so MOST census rows land destination-only today
    /// and gain their scroll anchor as the catalog fills; the
    /// per-destination anchor-less counts are pinned in
    /// `SettingsSearchIndexTests`, so a label-key rename that
    /// silently strips an existing match reds.
    let anchor: SettingsAnchor
    /// Breadcrumb above the label, outermost first — the
    /// destination, the local surface when one must be
    /// selected, the drawer the row hides inside.
    let path: [String]
    /// `.atRest` for catalog-only anchor rows — a tab or drawer
    /// title is on screen (or one honest click away) whenever
    /// its destination is.
    let tier: SettingTier
    var id: String {
        key.map(\.id) ?? "control/\(anchor.anchor ?? "none")"
    }
}

@MainActor
enum SettingsSearchIndex {
    /// The tiers with a Settings surface — the index's
    /// membership line. `.luaOnly`, `.internalOnly` and
    /// `.outsideSettings` rows have no row on any screen, so a
    /// result for one would land nowhere.
    static let indexedTiers: Set<SettingTier> = [
        .atRest, .showMore, .immediate,
    ]

    /// Labels resolve per locale and the census is static, so
    /// the built index is a pure function of the locale.
    /// `LocaleScopedRoot` rebuilds the search UI on a language
    /// switch, and the rebuilt rows read the new locale's cache
    /// entry.
    private static var cache = [String: [SettingsSearchIndexRow]]()

    static func rows() -> [SettingsSearchIndexRow] {
        let locale =
            LocalizationManager.shared.effectiveLocale
            ?? "system"
        if let built = cache[locale] { return built }
        let built = build()
        cache[locale] = built
        return built
    }

    /// Whether `key` is a search row on THIS machine. Beyond the
    /// tier line, two exclusions, both data-driven:
    ///
    /// - A `.dynamic`-labelled key composes its text per
    ///   instance (space names, per-instance keybinding rows),
    ///   so it has no static label to match or show; its
    ///   *family* stays findable through its container and
    ///   destination. Which keys these are is the census's
    ///   `SettingLabel.dynamic`, never a hand-kept list here.
    /// - A row gated on `.liquidGlassUnavailable` is HIDDEN on
    ///   machines that cannot render it (#390) — search must not
    ///   return a row that cannot exist on this machine, so the
    ///   index asks the same one predicate the renderer does
    ///   (`AppBarStyle.glassAvailable`).
    static func indexes(_ key: SettingKey) -> Bool {
        let placement = key.placement
        guard placement.area != nil,
            indexedTiers.contains(placement.tier),
            SettingsCensusLabel.label(for: key) != nil
        else { return false }
        let conditions =
            placement.gate?.runtimeConditions ?? []
        let gated = conditions.contains(.liquidGlassUnavailable)
        if gated, !AppBarStyle.glassAvailable { return false }
        return true
    }

    /// Destination order first (`thisProfile` + `wholeApp`, the
    /// order the old one-per-destination list already answered
    /// in); within a destination the census rows in declaration
    /// order, then the catalog-only anchor rows.
    private static func build() -> [SettingsSearchIndexRow] {
        let all = SettingKey.allCases.filter(indexes)
        let ordered =
            SettingsDestination.thisProfile
            + SettingsDestination.wholeApp
        return ordered.flatMap { destination in
            let entries = SettingsCatalog.entries(of: destination)
            let census = all.filter {
                $0.placement.area == destination.area
            }
            .map { row(for: $0, in: destination, entries) }
            return census
                + extras(
                    in: destination,
                    entries,
                    claimed: Set(
                        census.compactMap(\.anchor.anchor)
                    )
                )
        }
    }

    /// The catalog-only anchor rows: every control in the
    /// destination's catalog that no census row landed on — the
    /// mode tabs, drawer titles and switch chips the census does
    /// not model as settings. Derived from the two lists, so a
    /// control is a search row exactly once however it is
    /// declared.
    private static func extras(
        in destination: SettingsDestination,
        _ entries: [SettingsIndexEntry],
        claimed: Set<String>
    ) -> [SettingsSearchIndexRow] {
        entries.filter { !claimed.contains($0.control.id) }
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
                    synonyms: [],
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
        let labelKey: String? = {
            guard case .key(let k) = key.text.label else {
                return nil
            }
            return k
        }()
        let hit = entries.first { $0.control.key == labelKey }
        var path = [destination.title]
        if let surface = hit?.control.surface.displayName {
            path.append(surface)
        }
        if let parent = hit?.parent {
            path.append(parent.text)
        }
        return SettingsSearchIndexRow(
            key: key,
            label: SettingsCensusLabel.label(for: key) ?? key.id,
            synonyms: SettingsSearchSynonyms.terms(for: key),
            destination: destination,
            anchor: hit.map {
                SettingsAnchor(
                    destination: destination,
                    surface: $0.control.surface,
                    anchor: $0.control.id
                )
            } ?? SettingsAnchor(destination: destination),
            path: path,
            tier: key.placement.tier
        )
    }
}

extension SettingsSurface {
    /// The surface's own user-facing name, reusing the exact
    /// tuples of the controls that select it, or nil for `.main`.
    @MainActor var displayName: String? {
        switch self {
        case .main: return nil
        case .layoutMode(let mode): return mode.displayName
        }
    }
}
