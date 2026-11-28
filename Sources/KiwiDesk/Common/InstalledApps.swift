import AppKit
import os

/// The apps installed on disk, one process-lifetime scan of
/// `/Applications`, `/System/Applications` and `~/Applications`,
/// shared by Settings' app pickers and KiwiHub's Applications
/// section (#3704). The scan is slow: a hotkey path reads
/// `scanned`, which never starts it.
enum InstalledApps {
    /// An app by bundle id (lowercased) and display name.
    struct App: Hashable, Identifiable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    private static let diskScan: (apps: [App], iconPaths: [String: String]) = {
        let manager = FileManager.default
        let roots = [
            "/Applications",
            "/System/Applications",
            manager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications").path,
        ]
        var byID: [String: App] = [:]
        var paths: [String: String] = [:]
        for root in roots {
            for path in appPaths(under: root) {
                let url = URL(fileURLWithPath: path)
                guard
                    let id = Bundle(url: url)?
                        .bundleIdentifier?.lowercased()
                else { continue }
                byID[id] = App(
                    bundleID: id,
                    name: localizedName(url: url, path: path)
                )
                paths[id] = path
            }
        }
        let scan = (Array(byID.values), paths)
        scanDone.withLock { $0 = true }
        return scan
    }()

    /// Whether `diskScan` has finished.
    private static let scanDone = OSAllocatedUnfairLock(
        initialState: false
    )

    /// Every app the scan found, scanning first where it has not.
    static var disk: [App] { diskScan.apps }

    /// Bundle id to the app's path on disk.
    static var iconPaths: [String: String] { diskScan.iconPaths }

    /// The scan's apps, nil until something finished it: never
    /// scans, so KiwiHub's open may ask it.
    static var scanned: [App]? {
        scanDone.withLock { $0 } ? diskScan.apps : nil
    }

    /// Runs the scan off the main thread, ahead of the first read.
    static func warm() {
        Task.detached(priority: .utility) { _ = diskScan }
    }

    /// Every `.app` under `root`, one folder deep as well as at
    /// the top (#1279), so `/System/Applications/Utilities` and a
    /// vendor folder are reached. A bundle's own contents are
    /// skipped, and depth stops at one folder, where vendors put
    /// apps: an unbounded walk would read every bundle's resources.
    static func appPaths(under root: String) -> [String] {
        let manager = FileManager.default
        var found: [String] = []
        for entry
            in (try? manager.contentsOfDirectory(atPath: root))
            ?? []
        {
            let path = "\(root)/\(entry)"
            if entry.hasSuffix(".app") {
                found.append(path)
                continue
            }
            var isDirectory: ObjCBool = false
            guard
                manager.fileExists(
                    atPath: path,
                    isDirectory: &isDirectory
                ), isDirectory.boolValue
            else { continue }
            for nested
                in (try? manager.contentsOfDirectory(atPath: path))
                ?? [] where nested.hasSuffix(".app")
            {
                found.append("\(path)/\(nested)")
            }
        }
        return found
    }

    #if DEBUG
        /// The walk, for `AppScanDepthTests`. `#if DEBUG` so a
        /// production read reds the release build (tests.md).
        static func appPathsForTesting(
            under root: String
        ) -> [String] {
            appPaths(under: root)
        }
    #endif

    /// The user-language display name via Spotlight metadata, else
    /// FileManager's, without the soft hyphen some localized names
    /// carry, which would leak a line break or skew a sort key.
    static func localizedName(url: URL, path: String) -> String {
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
        let shown = FileManager.default.displayName(atPath: path)
        return shown.hasSuffix(".app")
            ? String(shown.dropLast(4)) : shown
    }
}
