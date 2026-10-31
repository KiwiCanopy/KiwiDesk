import AppKit
import KiwiDeskCore
import UniformTypeIdentifiers

/// Cache for downsized application icons (#263, `InstalledApp`,
/// `AppRuleIdentity`).
@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    /// Row-size icon side length.
    nonisolated static let side: CGFloat = 20

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

    /// A bundle id's icon as fixed pixels, made once (#1740): the
    /// system icon draws lazily and can change between two renders
    /// in one process, and a gallery PNG must draw the same bytes.
    func fixedIcon(forBundleID id: String) -> NSImage {
        let key = "fixed:" + id.lowercased()
        if let hit = memo[key] { return hit }
        let source =
            NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: id
            ).map { Self.fileIcon(atPath: $0.path) }
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        let image = Self.rasterized(source) ?? source
        memo[key] = image
        return image
    }

    /// The pixels a fixed icon is drawn at.
    private static let fixedPixels = 256

    /// `image` drawn once into a bitmap of its own, inside a saved
    /// graphics state, so a render in progress keeps its context.
    private static func rasterized(_ image: NSImage) -> NSImage? {
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: fixedPixels,
                pixelsHigh: fixedPixels,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: rep)
        else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        let side = CGFloat(fixedPixels)
        image.draw(
            in: CGRect(x: 0, y: 0, width: side, height: side),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        context.flushGraphics()
        let fixed = NSImage(size: image.size)
        fixed.addRepresentation(rep)
        return fixed
    }

    /// The icon for a list entry (#2103 ruling 27): the app's where
    /// the entry is a bundle id an app answers to, else the generic
    /// program icon a process without a bundle id shows.
    func icon(forListKey key: String) -> NSImage {
        let id = "list:" + key.lowercased()
        if let hit = memo[id] { return hit }
        let image =
            NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: key
            ) == nil
            ? processIcon : icon(forBundleID: key)
        memo[id] = image
        return image
    }

    /// The generic program icon of a process without a bundle id.
    var processIcon: NSImage {
        if let hit = memo["process:"] { return hit }
        let image = Self.downsized(
            NSWorkspace.shared.icon(for: .unixExecutable)
        )
        memo["process:"] = image
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
                        Self.fileIcon(atPath: path)
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
            return downsized(fileIcon(atPath: url.path))
        }
        return downsized(
            NSWorkspace.shared.icon(
                for: .applicationBundle
            )
        )
    }

    /// The icon of the bundle at `path`, symlinks resolved first:
    /// macOS 27 links `/Applications/Safari.app` into its cryptex,
    /// and a link path draws the alias arrow (#2819).
    static func fileIcon(atPath path: String) -> NSImage {
        NSWorkspace.shared.icon(
            forFile: URL(fileURLWithPath: path)
                .resolvingSymlinksInPath().path
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
