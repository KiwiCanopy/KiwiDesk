import KiwiDeskCore

/// Static settings search index row mapping census setting or catalog anchor
/// (#678).
struct SettingsSearchIndexRow: Identifiable, Equatable {
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
    static let indexedTiers: Set<SettingTier> = [
        .atRest, .showMore, .immediate,
    ]

    /// Locale-keyed search index cache.
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

    /// Tests whether key should be indexed on current runtime environment
    /// (#390).
    static func indexes(_ key: SettingKey) -> Bool {
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
        return true
    }

    /// Builds index in destination order: census settings followed by
    /// catalog-only anchors.
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
        let labelKey: String? = {
            guard case .key(let k) = key.text.label else {
                return nil
            }
            return k
        }()
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
