import AppKit
import KiwiDeskCore

/// The launch behavior an Open-Applications binding encodes,
/// derived from its `lua` verb rather than a persisted field
/// (#334) — so surfacing the choice adds no `KeyBinding` shape to
/// migrate or parity-test. Both verbs already dispatch to the same
/// engine helper (`launch(newInstance:)`); the GUI only exposes the
/// flag. Default is `openOrFocus`, the single most useful behavior.
enum AppLaunchBehavior: String, CaseIterable {
    /// `pull_or_spawn` — pull a running instance into the current
    /// space, or launch it if absent. The default.
    case openOrFocus
    /// `spawn_new` — always launch a fresh instance, even when one
    /// is already running.
    case openNew

    /// The Lua verb this behavior dispatches to.
    var verb: String {
        switch self {
        case .openOrFocus: return "pull_or_spawn"
        case .openNew: return "spawn_new"
        }
    }
}

/// The installed-application catalog and the app-launch command
/// inverse, split from `KeybindingCatalog` to stay under the
/// file-size ceiling. Apps are identified by bundle id (the
/// stable, locale- and rename-proof key — see `AppRef`) and
/// shown by their localized display name.
extension KeybindingCatalog {
    /// The Open-Applications action for this bundle id and launch
    /// behavior. Paired with `appBundleID(from:)` /
    /// `appLaunchBehavior(from:)`, its exact inverse. Behavior
    /// defaults to open-or-focus so existing call sites keep their
    /// meaning.
    static func appCommand(
        _ bundleID: String,
        behavior: AppLaunchBehavior = .openOrFocus
    ) -> String {
        "KiwiDesk.\(behavior.verb)(\"\(bundleID)\")"
    }

    /// The bundle id inside `appCommand`'s output, or nil when
    /// `lua` isn't exactly one of the app-launch calls — the
    /// inverse used by import classification. Matches either verb.
    static func appBundleID(from lua: String) -> String? {
        parseAppCommand(lua)?.bundleID
    }

    /// The launch behavior `lua` encodes, or nil when it isn't an
    /// app-launch call. The sibling inverse to `appBundleID(from:)`.
    static func appLaunchBehavior(
        from lua: String
    ) -> AppLaunchBehavior? {
        parseAppCommand(lua)?.behavior
    }

    /// Decomposes an app-launch Lua call into its bundle id and
    /// behavior, or nil when `lua` isn't exactly such a call. An
    /// embedded quote means escaped content the app menu never
    /// authors, so such Lua stays unmatched.
    private static func parseAppCommand(
        _ lua: String
    ) -> (bundleID: String, behavior: AppLaunchBehavior)? {
        let suffix = "\")"
        for behavior in AppLaunchBehavior.allCases {
            let prefix = "KiwiDesk.\(behavior.verb)(\""
            guard lua.hasPrefix(prefix), lua.hasSuffix(suffix),
                lua.count > prefix.count + suffix.count
            else { continue }
            let inner = lua.dropFirst(prefix.count)
                .dropLast(suffix.count)
            guard !inner.contains("\"") else { continue }
            return (String(inner), behavior)
        }
        return nil
    }

    /// One app a picker can target: the bundle identifier is
    /// the stored identity (stable across locale and rename —
    /// see `AppRef`), the localized display name is what's
    /// shown. Apps with no bundle id (rare unbundled helpers)
    /// can't be targeted by a rule and are dropped.
    struct InstalledApp: Hashable, Identifiable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    /// The single disk scan under the standard roots, run once:
    /// the app catalog plus each app's path for the icon cache
    /// to warm from. De-duplicated by bundle id (lower-cased,
    /// matching the normalized `AppRef.bundleID`).
    private static let diskScan:
        (apps: [InstalledApp], iconPaths: [String: String]) = {
            let manager = FileManager.default
            let roots = [
                "/Applications",
                "/System/Applications",
                manager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications").path,
            ]
            var byID: [String: InstalledApp] = [:]
            var paths: [String: String] = [:]
            for root in roots {
                let contents =
                    (try? manager.contentsOfDirectory(
                        atPath: root
                    )) ?? []
                for entry in contents
                where entry.hasSuffix(".app") {
                    let path = "\(root)/\(entry)"
                    let url = URL(fileURLWithPath: path)
                    guard
                        let id = Bundle(url: url)?
                            .bundleIdentifier?.lowercased()
                    else { continue }
                    byID[id] = InstalledApp(
                        bundleID: id,
                        name: localizedName(url: url, path: path)
                    )
                    paths[id] = path
                }
            }
            return (Array(byID.values), paths)
        }()

    /// Apps discoverable on disk under the standard roots.
    private static var diskApps: [InstalledApp] { diskScan.apps }

    /// Bundle id → app path for every disk app, the seed the
    /// icon cache warms from (running apps outside the scanned
    /// roots resolve lazily on miss). Frozen for process life,
    /// so the cache needs no invalidation.
    static var diskAppIconPaths: [String: String] {
        diskScan.iconPaths
    }

    /// The picker list: disk apps unioned with currently
    /// running apps, sorted by display name. Running apps fill
    /// in bundles outside the scanned roots — Finder (in
    /// /System/Library/CoreServices) most notably — without
    /// scanning the noisy system directories for the handful of
    /// user-facing apps they hold.
    static var installedApps: [InstalledApp] {
        var byID = Dictionary(
            diskApps.map { ($0.bundleID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier?.lowercased(),
                byID[id] == nil
            else { continue }
            // Only fills bundles outside the scanned roots
            // (Finder in CoreServices). Name via the same Spotlight
            // resolver so it's localized and matches the disk
            // entries; `localizedName` (the app's own) is the
            // fallback when the bundle has no URL.
            let name =
                app.bundleURL.map {
                    localizedName(url: $0, path: $0.path)
                } ?? app.localizedName ?? id
            byID[id] = InstalledApp(bundleID: id, name: name)
        }
        return byID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name)
                == .orderedAscending
        }
    }

    /// A one-shot snapshot of `installedApps` for the picker,
    /// computed on first access and cached for process life. The
    /// popover reads this directly, so its list is fully
    /// populated the instant it renders — no empty-then-fill race
    /// through view state — and isn't rebuilt on every keystroke.
    /// The trade is that an app launched mid-session (outside the
    /// scanned disk roots) won't appear until relaunch; disk apps,
    /// the bulk, are already frozen for process life.
    static let installedAppsSnapshot: [InstalledApp] = installedApps

    /// Process-life `bundleID → localized name` index over the
    /// snapshot, so `displayName(forBundleID:)` resolves an
    /// installed app with a dictionary hit instead of a live
    /// `NSWorkspace` + Spotlight read. Immutable (`static let`), so
    /// it's concurrency-safe and shared by every render that
    /// resolves or sorts app rows (#333 sorts by display name, so
    /// the App Rules list would otherwise re-hit Spotlight per app
    /// on every pass — a §5 main-thread cost).
    static let installedNameByID: [String: String] =
        Dictionary(
            installedAppsSnapshot.map { ($0.bundleID, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

    /// The localized display name for a bundle id, for showing
    /// a stored rule or binding whose identity is the id. Routed
    /// through the same `localizedName` resolver as the picker,
    /// so the two surfaces agree for any installed app. Falls
    /// back to the id itself when the app isn't installed.
    static func displayName(forBundleID id: String) -> String {
        let id = id.lowercased()
        // The snapshot covers every app present at launch; a live
        // lookup only remains for one installed mid-session.
        if let name = installedNameByID[id] { return name }
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: id
        ) {
            return localizedName(url: url, path: url.path)
        }
        return id
    }

    /// The app's user-language display name, the single resolver
    /// both the picker and `displayName(forBundleID:)` use.
    /// Reads Spotlight's `kMDItemDisplayName` — the same index
    /// Finder, the Dock, and Spotlight read, so it localizes
    /// ("Vorschau", "Systemeinstellungen") where a process-local
    /// bundle lookup can't (KiwiDesk ships an English-only bundle,
    /// localizing its own GUI via a JSON catalog, not `.lproj`).
    /// Strips a soft hyphen some localized names carry
    /// ("System\u{00AD}einstellungen") so it never leaks a line
    /// break into a label or skews a sort/search key. Falls back
    /// to `FileManager`'s display name when Spotlight has no entry
    /// (indexing off, a just-installed or atypical bundle).
    private static func localizedName(
        url: URL,
        path: String
    ) -> String {
        if let item = NSMetadataItem(url: url),
            let name = item.value(
                forAttribute: kMDItemDisplayName as String
            ) as? String
        {
            let clean = name.replacingOccurrences(
                of: "\u{00AD}",
                with: ""
            )
            let base =
                clean.hasSuffix(".app")
                ? String(clean.dropLast(4)) : clean
            if !base.isEmpty { return base }
        }
        return appDisplayName(path: path)
    }

    /// `FileManager`'s display name for a bundle, without the
    /// ".app" extension — the fallback when Spotlight can't name
    /// the app. Resolves in KiwiDesk's English-only process, so a
    /// CoreServices-localized system app reads in English here;
    /// the stored identity is the bundle id regardless (`AppRef`).
    private static func appDisplayName(path: String) -> String {
        let shown = FileManager.default.displayName(
            atPath: path
        )
        return shown.hasSuffix(".app")
            ? String(shown.dropLast(4)) : shown
    }
}
