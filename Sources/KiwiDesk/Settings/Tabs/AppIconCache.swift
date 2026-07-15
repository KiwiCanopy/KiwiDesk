import AppKit
import KiwiDeskCore

/// The app-picker icon memo (#263), kept off `InstalledApp` so
/// that value stays a pure `Hashable`/`Sendable` identity. Keyed
/// by the lower-cased bundle id, holding icons downsized to the
/// 20 pt row size (`AppRuleRow.appIcon`). `warm()` fills it off
/// the disk-app paths asynchronously so the first popover open
/// finds it hot; running apps outside the scanned roots resolve
/// lazily on miss. `diskApps` is frozen for process life, so the
/// memo is never invalidated.
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    /// The row size icons are drawn at, matching the App Rules
    /// header icon and the picker list rows.
    static let side: CGFloat = 20

    private var memo: [String: NSImage] = [:]
    private var warming = false

    private init() {}

    /// The icon for a bundle id at row size. A warmed disk app
    /// hits the memo; a running-app miss resolves and stores it
    /// now (a handful of apps — no spike).
    func icon(forBundleID id: String) -> NSImage {
        let key = id.lowercased()
        if let hit = memo[key] { return hit }
        let image = Self.resolve(bundleID: key)
        memo[key] = image
        return image
    }

    /// Warm the memo off the disk-app paths, once per process.
    /// Interleaved with `Task.yield()` so the ~150–300 icon
    /// loads and downsizes never land as one synchronous spike
    /// on the first open.
    func warm() {
        guard !warming else { return }
        warming = true
        Task { @MainActor in
            for (id, path) in KeybindingCatalog.diskAppIconPaths {
                if memo[id] == nil {
                    memo[id] = Self.downsized(
                        NSWorkspace.shared.icon(forFile: path)
                    )
                }
                await Task.yield()
            }
        }
    }

    /// Resolve a bundle id's icon from its installed URL, or the
    /// generic app placeholder when it isn't installed.
    private static func resolve(bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) {
            return downsized(
                NSWorkspace.shared.icon(forFile: url.path)
            )
        }
        return downsized(
            NSWorkspace.shared.icon(
                for: .applicationBundle
            )
        )
    }

    /// A row-size image over the full-resolution icon — the
    /// icon carries megabytes of reps we never show that big.
    /// The drawing handler redraws at whatever backing scale the
    /// display asks for, so the icon stays crisp on Retina (a
    /// `lockFocus` bitmap would bake one environment-fixed rep).
    private static func downsized(_ image: NSImage) -> NSImage {
        let target = NSSize(width: side, height: side)
        return NSImage(size: target, flipped: false) { rect in
            image.draw(
                in: rect,
                from: .zero,
                operation: .copy,
                fraction: 1
            )
            return true
        }
    }
}
