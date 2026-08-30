import AppKit
import KiwiDeskCore

/// Cache for downsized application icons (#263, `InstalledApp`,
/// `AppRuleRow.appIcon`).
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    /// Row-size icon side length.
    static let side: CGFloat = 20

    private var memo: [String: NSImage] = [:]
    private var warming = false

    private init() {}

    /// The icon for a bundle id at row size.
    func icon(forBundleID id: String) -> NSImage {
        let key = id.lowercased()
        if let hit = memo[key] { return hit }
        let image = Self.resolve(bundleID: key)
        memo[key] = image
        return image
    }

    /// Asynchronously warms the icon memo for disk applications.
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

    /// Downsizes icon to target row size with custom drawing handler.
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
