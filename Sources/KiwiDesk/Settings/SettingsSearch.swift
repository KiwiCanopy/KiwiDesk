import KiwiDeskCore

/// Settings search results model and query engine (#678 turn 11).
enum SettingsSearchResult: Identifiable, Equatable {
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

/// User-named settings search target (spec 11a, `PaletteStore`).
struct SettingsSearchPlace: Identifiable, Equatable {
    /// No `.palette` case, deliberately: `PaletteStore` is
    /// stateless and file-backed, so palette names have no
    /// in-memory production source yet — a kind nothing can feed
    /// is a seam without a consumer. It joins WITH the cache seam.
    enum Kind: String, CaseIterable {
        case space, profile, appRule
    }

    let kind: Kind
    let name: String
    let anchor: SettingsAnchor
    var id: String { "\(kind.rawValue)/\(name)" }
}

/// In-memory search evaluation context.
struct SettingsSearchContext {
    var editingStoredProfile = false
    var mode: SettingsMode = .simple
    var displayCount = 1
    var spaces: [String] = []
    var profiles: [String] = []
    var appRules: [String] = []

    /// Exhaustive by construction: a new `Kind` fails to compile
    /// here (and in `Kind.destination`) before it can ship as a
    /// kind no context feeds (architect review 2026-08-10).
    func names(of kind: SettingsSearchPlace.Kind) -> [String] {
        switch kind {
        case .space: return spaces
        case .profile: return profiles
        case .appRule: return appRules
        }
    }
}

extension SettingsSearchPlace.Kind {
    var destination: SettingsDestination {
        switch self {
        case .space: return .spaces
        case .profile: return .profiles
        case .appRule: return .appRules
        }
    }
}

/// Search result groups for settings rows and user-named places.
struct SettingsSearchResults: Equatable {
    var settings: [SettingsSearchResult] = []
    var places: [SettingsSearchResult] = []
    var flat: [SettingsSearchResult] { settings + places }
    var isEmpty: Bool { settings.isEmpty && places.isEmpty }
}

@MainActor
enum SettingsSearch {
    /// Maximum matches displayed under "Made by you" (spec 11a).
    static let placesCap = 5

    /// Evaluates query against search index and user places (`searchMatches`).
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

    /// Whether selecting result triggers Power User mode promotion
    /// (`HomeCardOrder.isOffered`, `ensureModeAdmits`).
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

    /// Matches named entities capped at `placesCap` (guard-prover 2026-08-10).
    private static func placeResults(
        _ query: String,
        _ context: SettingsSearchContext
    ) -> [SettingsSearchResult] {
        let kinds = Kind.allCases.map { kind in
            (kind, context.names(of: kind), kind.destination)
        }
        // No reachability filter, on purpose: every place kind
        // lands on a destination #18 never hides, so a filter
        // would be dead code no test can red (guard-prover,
        // 2026-08-10). A NEW kind whose destination can be
        // withheld owes the filter back — with a test that reds.
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
        return matched.prefix(placesCap)
            .map(SettingsSearchResult.place)
    }

    private typealias Kind = SettingsSearchPlace.Kind
}
