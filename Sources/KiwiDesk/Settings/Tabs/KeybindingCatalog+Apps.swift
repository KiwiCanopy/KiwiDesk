import AppKit
import KiwiDeskCore

/// The installed-application catalog and the `pull_or_spawn`
/// command inverse, split from `KeybindingCatalog` to stay under
/// the file-size ceiling. Apps are identified by bundle id (the
/// stable, locale- and rename-proof key — see `AppRef`) and
/// shown by their localized display name.
extension KeybindingCatalog {
    /// The Open-Applications action that pulls or launches the
    /// app with this bundle id. Paired with `appBundleID(from:)`,
    /// its exact inverse.
    static func appCommand(_ bundleID: String) -> String {
        "KiwiDesk.pull_or_spawn(\"\(bundleID)\")"
    }

    /// The bundle id inside `appCommand`'s output, or nil when
    /// `lua` isn't exactly that call — the inverse used by import
    /// classification. An embedded quote means escaped content the
    /// app menu never authors, so such Lua stays unmatched.
    static func appBundleID(from lua: String) -> String? {
        let prefix = "KiwiDesk.pull_or_spawn(\""
        let suffix = "\")"
        guard lua.hasPrefix(prefix), lua.hasSuffix(suffix),
            lua.count > prefix.count + suffix.count
        else { return nil }
        let inner = lua.dropFirst(prefix.count)
            .dropLast(suffix.count)
        guard !inner.contains("\"") else { return nil }
        return String(inner)
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

    /// Apps discoverable on disk under the standard roots,
    /// scanned once. De-duplicated by bundle id (lower-cased,
    /// matching the normalized `AppRef.bundleID`).
    private static let diskApps: [InstalledApp] = {
        let manager = FileManager.default
        let roots = [
            "/Applications",
            "/System/Applications",
            manager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications").path,
        ]
        var byID: [String: InstalledApp] = [:]
        for root in roots {
            let contents =
                (try? manager.contentsOfDirectory(
                    atPath: root
                )) ?? []
            for entry in contents where entry.hasSuffix(".app") {
                let path = "\(root)/\(entry)"
                guard
                    let id = Bundle(
                        url: URL(fileURLWithPath: path)
                    )?.bundleIdentifier?.lowercased()
                else { continue }
                byID[id] = InstalledApp(
                    bundleID: id,
                    name: appDisplayName(path: path)
                )
            }
        }
        return Array(byID.values)
    }()

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
            byID[id] = InstalledApp(
                bundleID: id,
                name: app.localizedName ?? id
            )
        }
        return byID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name)
                == .orderedAscending
        }
    }

    /// The localized display name for a bundle id, for showing
    /// a stored rule or binding whose identity is the id. Falls
    /// back to the id itself when the app isn't installed.
    static func displayName(forBundleID id: String) -> String {
        let id = id.lowercased()
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: id
        ) {
            return appDisplayName(path: url.path)
        }
        return id
    }

    /// The Finder-localized display name of an app bundle,
    /// without the ".app" extension.
    private static func appDisplayName(path: String) -> String {
        let shown = FileManager.default.displayName(
            atPath: path
        )
        return shown.hasSuffix(".app")
            ? String(shown.dropLast(4)) : shown
    }
}
