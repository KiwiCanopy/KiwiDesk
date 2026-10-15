import Foundation
import KiwiDeskCore

/// What the shared app picker's popover lists (#2103 ruling 27): an
/// optional "On screen now" section, then "All apps". Pure, so the
/// rules the owner ruled are held without a view.
enum AppPickerSections {
    typealias App = KeybindingCatalog.InstalledApp

    /// The two lists for `query`: the search filters both — never
    /// hides "On screen now", where a bundle-less process exists
    /// alone — an app on screen is listed there only, and every
    /// app whose key `exclude` holds is left out of both. Keys
    /// compare lowercased: `AppRef` lowercases a bundle id, and an
    /// entry may be a process name.
    static func lists(
        onScreen: [OnScreenApp],
        installed: [App],
        exclude: Set<String>,
        query: String
    ) -> (onScreen: [OnScreenApp], all: [App]) {
        let excluded = Set(exclude.map { $0.lowercased() })
        let shown =
            onScreen
            .filter { !excluded.contains($0.key) }
            .sorted {
                $0.name.localizedStandardCompare($1.name)
                    == .orderedAscending
            }
        let onScreenKeys = Set(shown.map(\.key))
        let rest = installed.filter {
            let key = $0.bundleID.lowercased()
            return !excluded.contains(key) && !onScreenKeys.contains(key)
        }
        let query = query.trimmed
        guard !query.isEmpty else { return (shown, rest) }
        return (
            shown.filter {
                $0.name.searchMatches(query) || $0.key.searchMatches(query)
            },
            AppPickerFilter.matching(rest, query: query)
        )
    }
}
