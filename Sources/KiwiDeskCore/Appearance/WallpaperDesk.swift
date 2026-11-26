import AppKit
import Foundation

/// The machine half of a look's picture (#3478): reading which
/// picture a screen shows and setting one, through the public
/// `NSWorkspace` calls alone. A set reaches the screen's CURRENT
/// Desktop only, and outlives KiwiDesk. Both `makeTestCore` twins
/// pin `refused`, since a set is a write macOS keeps.
struct WallpaperDesk {
    /// The picture `display` shows now: the URL macOS reports,
    /// never the file, so it raises no folder prompt.
    var current: @MainActor (DisplayID) -> URL?
    /// Sets `url` on `display`'s current Desktop; whether macOS took
    /// the call (the read-back is its confirmation).
    var set: @MainActor (URL, DisplayID) -> Bool

    static let live = WallpaperDesk(
        current: { display in
            TilingEngine.screen(for: display).flatMap {
                NSWorkspace.shared.desktopImageURL(for: $0)
            }
        },
        set: { url, display in
            guard let screen = TilingEngine.screen(for: display) else {
                return false
            }
            // Keeps the screen's own scaling and fill colour.
            let options =
                NSWorkspace.shared.desktopImageOptions(
                    for: screen
                ) ?? [:]
            do {
                try NSWorkspace.shared.setDesktopImageURL(
                    url,
                    for: screen,
                    options: options
                )
                return true
            } catch {
                return false
            }
        }
    )

    static let refused = WallpaperDesk(
        current: { _ in nil },
        set: { _, _ in false }
    )
}

/// The copies macOS wears (#3478 ▸ Library): a folder on this Mac
/// holding the pictures last set, so a library cleanup, a reset or
/// a sync deletion never pulls a picture off screen.
struct WallpaperMachineCopies {
    let directory: URL

    init(machineDirectory: URL) {
        directory = machineDirectory.appendingPathComponent(
            "wallpaper",
            isDirectory: true
        )
    }

    /// Where the copy of `name` lives.
    func url(of name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// The library name `url` is this Mac's copy of, nil for any
    /// other picture: the one "is this our copy" answer, read from
    /// the URL alone and opening no file (#3478).
    func libraryName(of url: URL) -> String? {
        let name = url.lastPathComponent
        guard LookWallpaper.isLibraryName(name),
            url.deletingLastPathComponent().standardizedFileURL.path
                == directory.standardizedFileURL.path
        else { return nil }
        return name
    }

    /// Copies each of `names` in from `library`, then drops every
    /// other copy the library no longer holds, so a picture is pulled
    /// off a Desktop only once no look keeps it. Answers the names
    /// now here.
    @discardableResult
    func keep(
        _ names: Set<String>,
        from library: WallpaperLibrary
    ) -> Set<String> {
        let files = FileManager.default
        try? files.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        var here: Set<String> = []
        for name in names {
            let copy = url(of: name)
            if files.fileExists(atPath: copy.path) {
                here.insert(name)
                continue
            }
            if (try? files.copyItem(at: library.url(of: name), to: copy))
                != nil
            {
                here.insert(name)
            }
        }
        let present =
            (try? files.contentsOfDirectory(atPath: directory.path))
            ?? []
        for stale in present
        where !names.contains(stale) && !library.has(stale) {
            try? files.removeItem(at: url(of: stale))
        }
        return here
    }
}

/// A look's picture's machine touches (#3478), in one home: the
/// wallpaper reads and sets, whether a set is armed yet, and the
/// Trash. Both `makeTestCore` twins pin `desk` to `refused` and
/// `trash` to a plain delete, since a set outlives this process and
/// a suite must never fill the developer's Trash.
@MainActor
final class LookWallpaperSeams {
    var desk = WallpaperDesk.live
    /// False until boot's config load ran: a launch is no wear.
    var armed = false
    var trash: (URL) throws -> Void = {
        try FileManager.default.trashItem(at: $0, resultingItemURL: nil)
    }
}
