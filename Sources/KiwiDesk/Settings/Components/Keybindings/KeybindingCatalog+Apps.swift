import AppKit
import KiwiDeskCore
import os

/// What an Open applications shortcut does with its app (#334,
/// #1510), derived from the binding's `lua` verb, never a
/// persisted field — so there is no `KeyBinding` shape to migrate
/// or parity-test.
enum AppShortcutAction: String, CaseIterable {
    case openOrFocus
    case openNew
    /// Brings the app's windows to the user (#1510).
    case gather

    var verb: String {
        switch self {
        case .openOrFocus: return "focus_or_spawn"
        case .openNew: return "spawn_new"
        case .gather: return "gather"
        }
    }
}

/// Application catalog and command parser helpers for app shortcuts (#334,
/// #333).
extension KeybindingCatalog {
    /// Formats Lua command for launching bundle identifier with specified
    /// action.
    static func appCommand(
        _ bundleID: String,
        action: AppShortcutAction = .openOrFocus
    ) -> String {
        "KiwiDesk.\(action.verb)(\"\(bundleID)\")"
    }

    /// Extracts bundle identifier from app-launch Lua command string.
    static func appBundleID(from lua: String) -> String? {
        parseAppCommand(lua)?.bundleID
    }

    /// Extracts action from app-launch Lua command string.
    static func appShortcutAction(
        from lua: String
    ) -> AppShortcutAction? {
        parseAppCommand(lua)?.action
    }

    /// actions already bound for `bundleID` in given keybindings
    /// (#334).
    static func takenActions(
        for bundleID: String,
        in bindings: [KeyBinding],
        excluding id: UUID? = nil
    ) -> Set<AppShortcutAction> {
        Set(
            bindings.filter {
                $0.kind == .application && $0.id != id
                    && appBundleID(from: $0.lua) == bundleID
            }
            .map { appShortcutAction(from: $0.lua) ?? .openOrFocus }
        )
    }

    /// First available action for `bundleID` (#334).
    static func firstAvailableAction(
        for bundleID: String,
        in bindings: [KeyBinding]
    ) -> AppShortcutAction? {
        let taken = takenActions(for: bundleID, in: bindings)
        return AppShortcutAction.allCases.first {
            !taken.contains($0)
        }
    }

    /// nil unless `lua` is exactly an app-launch call; an embedded
    /// quote means escaped content the app menu never authors.
    private static func parseAppCommand(
        _ lua: String
    ) -> (bundleID: String, action: AppShortcutAction)? {
        let suffix = "\")"
        for action in AppShortcutAction.allCases {
            let prefix = "KiwiDesk.\(action.verb)(\""
            guard lua.hasPrefix(prefix), lua.hasSuffix(suffix),
                lua.count > prefix.count + suffix.count
            else { continue }
            let inner = lua.dropFirst(prefix.count)
                .dropLast(suffix.count)
            guard !inner.contains("\"") else { continue }
            return (String(inner), action)
        }
        return nil
    }

    /// Target application with bundle ID and display name.
    typealias InstalledApp = InstalledApps.App

    private static var diskApps: [InstalledApp] { InstalledApps.disk }

    /// Bundle ID to application file path mapping for disk applications.
    static var diskAppIconPaths: [String: String] {
        InstalledApps.iconPaths
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
                    InstalledApps.localizedName(url: $0, path: $0.path)
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
    static let installedNameByID: [String: String] = {
        let names = Dictionary(
            installedAppsSnapshot.map { ($0.bundleID, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        snapshotBuilt.withLock { $0 = true }
        return names
    }()

    /// Whether `installedNameByID` exists yet (#3276).
    private static let snapshotBuilt = OSAllocatedUnfairLock(
        initialState: false
    )

    /// Resolves localized display name for bundle identifier (#333).
    static func displayName(forBundleID id: String) -> String {
        let id = id.lowercased()
        if let name = installedNameByID[id] { return name }
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: id
        ) {
            return InstalledApps.localizedName(url: url, path: url.path)
        }
        return id
    }

    /// The snapshot's name for an id, nil until something built the
    /// snapshot: never scans, so a hotkey path may ask it. It names
    /// an app LaunchServices no longer finds only when the snapshot
    /// predates the app's removal (#3276).
    static func snapshotName(forBundleID id: String) -> String? {
        guard snapshotBuilt.withLock({ $0 }) else { return nil }
        return installedNameByID[id.lowercased()]
    }
}
