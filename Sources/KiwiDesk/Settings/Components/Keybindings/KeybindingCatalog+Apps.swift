import AppKit
import KiwiDeskCore

/// Launch behavior for Open-Applications shortcut bindings (#334).
enum AppLaunchBehavior: String, CaseIterable {
    case openOrFocus
    case openNew

    var verb: String {
        switch self {
        case .openOrFocus: return "pull_or_spawn"
        case .openNew: return "spawn_new"
        }
    }
}

/// Application catalog and command parser helpers for app shortcuts (#334,
/// #333).
extension KeybindingCatalog {
    /// Formats Lua command for launching bundle identifier with specified
    /// behavior.
    static func appCommand(
        _ bundleID: String,
        behavior: AppLaunchBehavior = .openOrFocus
    ) -> String {
        "KiwiDesk.\(behavior.verb)(\"\(bundleID)\")"
    }

    /// Extracts bundle identifier from app-launch Lua command string.
    static func appBundleID(from lua: String) -> String? {
        parseAppCommand(lua)?.bundleID
    }

    /// Extracts launch behavior from app-launch Lua command string.
    static func appLaunchBehavior(
        from lua: String
    ) -> AppLaunchBehavior? {
        parseAppCommand(lua)?.behavior
    }

    /// Launch behaviors already bound for `bundleID` in given keybindings
    /// (#334).
    static func takenBehaviors(
        for bundleID: String,
        in bindings: [KeyBinding],
        excluding id: UUID? = nil
    ) -> Set<AppLaunchBehavior> {
        Set(
            bindings.filter {
                $0.kind == .application && $0.id != id
                    && appBundleID(from: $0.lua) == bundleID
            }
            .map { appLaunchBehavior(from: $0.lua) ?? .openOrFocus }
        )
    }

    /// First available launch behavior for `bundleID` (#334).
    static func firstAvailableBehavior(
        for bundleID: String,
        in bindings: [KeyBinding]
    ) -> AppLaunchBehavior? {
        let taken = takenBehaviors(for: bundleID, in: bindings)
        return AppLaunchBehavior.allCases.first {
            !taken.contains($0)
        }
    }

    /// Resolves preferred or available behavior when reassigning application
    /// row (#334).
    static func behaviorForAssignment(
        to bundleID: String,
        preferred: AppLaunchBehavior,
        in bindings: [KeyBinding],
        excluding id: UUID
    ) -> AppLaunchBehavior {
        let taken = takenBehaviors(
            for: bundleID,
            in: bindings,
            excluding: id
        )
        if !taken.contains(preferred) { return preferred }
        return AppLaunchBehavior.allCases.first {
            !taken.contains($0)
        } ?? preferred
    }

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

    /// Target application with bundle ID and display name.
    struct InstalledApp: Hashable, Identifiable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

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

    private static var diskApps: [InstalledApp] { diskScan.apps }

    /// Bundle ID to application file path mapping for disk applications.
    static var diskAppIconPaths: [String: String] {
        diskScan.iconPaths
    }

    /// Installed disk and running regular applications sorted by localized
    /// display name.
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

    /// Process-lifetime cached snapshot of installed applications.
    static let installedAppsSnapshot: [InstalledApp] = installedApps

    /// Process-lifetime dictionary mapping bundle ID to localized name (#333).
    static let installedNameByID: [String: String] =
        Dictionary(
            installedAppsSnapshot.map { ($0.bundleID, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

    /// Resolves localized display name for bundle identifier (#333).
    static func displayName(forBundleID id: String) -> String {
        let id = id.lowercased()
        if let name = installedNameByID[id] { return name }
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: id
        ) {
            return localizedName(url: url, path: url.path)
        }
        return id
    }

    /// Resolves user-language display name via Spotlight metadata or
    /// FileManager fallback.
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

    private static func appDisplayName(path: String) -> String {
        let shown = FileManager.default.displayName(
            atPath: path
        )
        return shown.hasSuffix(".app")
            ? String(shown.dropLast(4)) : shown
    }
}
