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

/// A row the app picker's cursor can sit on: an app in either
/// section, or the escape pinned below them.
enum AppPickerSlot: Hashable {
    case onScreen(String)
    case installed(String)
    case escape

    typealias Lists = (
        onScreen: [OnScreenApp],
        all: [KeybindingCatalog.InstalledApp]
    )

    /// The cursor's sequence over `lists`, in drawn order: on
    /// screen, all apps, then the escape, which ↓ past the last
    /// app reaches.
    static func sequence(of lists: Lists) -> [AppPickerSlot] {
        lists.onScreen.map { .onScreen($0.key) }
            + lists.all.map { .installed($0.bundleID) } + [.escape]
    }

    /// Where the cursor starts: the first app, nil for none — the
    /// escape is reached by a key or the pointer, never seeded.
    static func firstApp(of lists: Lists) -> AppPickerSlot? {
        sequence(of: lists).first { $0 != .escape }
    }

    /// The identity its row's `ForEach` gives it, which
    /// `ScrollViewProxy.scrollTo` reaches; nil for the escape,
    /// which sits outside the list.
    var rowID: String? {
        switch self {
        case .onScreen(let key): return key
        case .installed(let id): return id
        case .escape: return nil
        }
    }

    /// The bundle id of an installed app's row, nil otherwise.
    var installedID: String? {
        if case .installed(let id) = self { return id }
        return nil
    }
}
