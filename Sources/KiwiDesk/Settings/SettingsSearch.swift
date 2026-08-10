import KiwiDeskCore

/// The search result model (#678 turn 11): one row per census
/// setting from the static index, destination-title rows for
/// area names, and a capped Places group for the user's own
/// named things. Replaced `SidebarSearch`'s one-hit-per-
/// destination cap — that cap existed because a result could
/// not say WHICH row it meant; a per-setting index can, so a
/// query like "color" now lists each matching setting under its
/// own breadcrumb.
enum SettingsSearchResult: Identifiable, Equatable {
    /// The area name itself matched — the pane opens without
    /// scrolling (the tier-1 shape, kept).
    case destination(SettingsDestination)
    case setting(SettingsSearchIndexRow)
    case place(SettingsSearchPlace)

    var id: String {
        switch self {
        case .destination(let d): return "destination/\(d.rawValue)"
        case .setting(let row): return "setting/\(row.id)"
        case .place(let place): return "place/\(place.id)"
        }
    }

    var destination: SettingsDestination {
        switch self {
        case .destination(let d): return d
        case .setting(let row): return row.destination
        case .place(let place): return place.anchor.destination
        }
    }

    var anchor: SettingsAnchor {
        switch self {
        case .destination(let d): return SettingsAnchor(destination: d)
        case .setting(let row): return row.anchor
        case .place(let place): return place.anchor
        }
    }
}

/// One entry in the Places group (spec 11a): a thing the user
/// NAMED — a space, a profile, a palette, an app rule — findable
/// by that name, one entry per object, landing on the area that
/// owns it. Lua binding contents stay out (free text would swamp
/// everything), and values are not indexed at all.
struct SettingsSearchPlace: Identifiable, Equatable {
    enum Kind: String, CaseIterable {
        case space, profile, palette, appRule
    }

    let kind: Kind
    let name: String
    let anchor: SettingsAnchor
    var id: String { "\(kind.rawValue)/\(name)" }
}

/// Everything the result builder may consult — collected by the
/// CALLER from state already in memory. The search path itself
/// touches nothing else: no AX, no disk, no session. Palettes in
/// particular arrive as whatever list the model already holds;
/// search never triggers a store load.
struct SettingsSearchContext {
    var editingStoredProfile = false
    var mode: SettingsMode = .simple
    var displayCount = 1
    var spaces: [String] = []
    var profiles: [String] = []
    var palettes: [String] = []
    var appRules: [String] = []
}

/// The two result groups, in commit order: settings rows, then
/// Places. `flat` is the keyboard-navigation order.
struct SettingsSearchResults: Equatable {
    var settings: [SettingsSearchResult] = []
    var places: [SettingsSearchResult] = []
    var flat: [SettingsSearchResult] { settings + places }
    var isEmpty: Bool { settings.isEmpty && places.isEmpty }
}

@MainActor
enum SettingsSearch {
    /// The Places group's cap (spec 11a): the group exists to
    /// jump to a thing you named, not to enumerate your config.
    static let placesCap = 5

    /// Settings rows then Places, each internally ordered.
    /// Matching is `searchMatches` — the app's one predicate —
    /// over the localized label, the destination title and the
    /// English synonyms. Search indexes BOTH modes, always; the
    /// mode is mentioned nowhere but the result pill.
    static func results(
        query: String,
        context: SettingsSearchContext
    ) -> SettingsSearchResults {
        let query = query.trimmed
        guard !query.isEmpty else {
            return SettingsSearchResults()
        }
        return SettingsSearchResults(
            settings: settingsResults(query, context),
            places: placeResults(query, context)
        )
    }

    /// Whether committing `result` will flip the window into
    /// Power User mode — the result rows' pill and the only
    /// place search mentions the mode. Asks the one offer
    /// predicate (`HomeCardOrder.isOffered`), never a
    /// hand-negated copy: a destination not offered in the
    /// CURRENT mode is one `ensureModeAdmits` will promote for,
    /// which keeps the Monitors display-count promotion and the
    /// already-in-Power-User case both silent.
    static func switchesMode(
        _ result: SettingsSearchResult,
        context: SettingsSearchContext
    ) -> Bool {
        !HomeCardOrder.isOffered(
            result.destination,
            mode: context.mode,
            displayCount: context.displayCount,
            editingStoredProfile: context.editingStoredProfile
        )
    }

    private static func settingsResults(
        _ query: String,
        _ context: SettingsSearchContext
    ) -> [SettingsSearchResult] {
        let ordered =
            SettingsDestination.thisProfile
            + SettingsDestination.wholeApp
        let reachable = ordered.filter {
            $0.isReachable(
                editingStoredProfile: context.editingStoredProfile
            )
        }
        let rows = SettingsSearchIndex.rows()
        return reachable.flatMap { destination in
            var out: [SettingsSearchResult] = []
            if destination.title.searchMatches(query) {
                out.append(.destination(destination))
            }
            out += rows.filter {
                $0.destination == destination
                    && matches($0, query)
            }
            .map(SettingsSearchResult.setting)
            return out
        }
    }

    private static func matches(
        _ row: SettingsSearchIndexRow,
        _ query: String
    ) -> Bool {
        row.label.searchMatches(query)
            || row.synonyms.contains {
                $0.searchMatches(query)
            }
    }

    /// One entry per named object, kinds in a fixed order,
    /// capped at `placesCap` AFTER matching so the first five
    /// matches win, not the first five objects.
    private static func placeResults(
        _ query: String,
        _ context: SettingsSearchContext
    ) -> [SettingsSearchResult] {
        let kinds: [(Kind, [String], SettingsDestination)] = [
            (.space, context.spaces, .spaces),
            (.profile, context.profiles, .profiles),
            (.palette, context.palettes, .colors),
            (.appRule, context.appRules, .appRules),
        ]
        let matched = kinds.flatMap { kind, names, destination in
            names.filter { $0.searchMatches(query) }
                .map {
                    SettingsSearchPlace(
                        kind: kind,
                        name: $0,
                        anchor: SettingsAnchor(
                            destination: destination
                        )
                    )
                }
        }
        .filter {
            $0.anchor.destination.isReachable(
                editingStoredProfile: context.editingStoredProfile
            )
        }
        return matched.prefix(placesCap)
            .map(SettingsSearchResult.place)
    }

    private typealias Kind = SettingsSearchPlace.Kind
}
