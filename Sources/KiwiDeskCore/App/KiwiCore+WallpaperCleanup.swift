import Foundation

/// The library's cleanup (#3478 ▸ Cleanup): a picture goes to the
/// Trash once no look home names it. The homes are `looks.json`,
/// the shared look in `gui.json`, every profile's worn
/// `look_wallpaper` and the live settings — one walk, never a copy.
extension KiwiCore {
    /// Every library picture a look home names.
    func namedWallpapers() -> Set<String> {
        var names: Set<String> = []
        let looks = (try? lookLibrary.libraryLooks()) ?? []
        for look in looks { names.formUnion(look.wallpaper?.names ?? []) }
        if let shared = sharedLook {
            names.formUnion(shared.wallpaper?.names ?? [])
        }
        for profile in profiles.allProfiles() {
            names.formUnion(profile.settings.lookWallpaper?.names ?? [])
        }
        names.formUnion(tiler.settings.lookWallpaper?.names ?? [])
        return names
    }

    /// Trashes each of `candidates` no home names any more: after a
    /// look's picture is replaced or removed, or the look deleted.
    func trashUnnamedWallpapers(_ candidates: Set<String>) {
        guard !candidates.isEmpty else { return }
        let unnamed = candidates.subtracting(namedWallpapers())
        trashWallpapers(unnamed)
    }

    /// The launch and post-sync sweep: trashes every library file no
    /// look names that is older than `grace`, which covers a picture
    /// synced in ahead of the `looks.json` naming it.
    func sweepWallpapers(grace: TimeInterval = 7 * 24 * 3600) {
        let library = wallpaperLibrary
        let named = namedWallpapers()
        let now = wallClock()
        let stale = library.names().filter { name in
            guard !named.contains(name) else { return false }
            let attributes = try? FileManager.default.attributesOfItem(
                atPath: library.url(of: name).path
            )
            let date = attributes?[.modificationDate] as? Date ?? now
            return now.timeIntervalSince(date) > grace
        }
        trashWallpapers(Set(stale))
    }

    /// Writes a bundle's pictures, each re-hashed on the way in, so
    /// a name never disagrees with its bytes. A bundle from before
    /// pictures travelled carries none and leaves the library alone.
    func writeIncomingWallpapers(_ bundle: SetupBundle) {
        let library = wallpaperLibrary
        for (name, data) in bundle.wallpapers ?? [:] {
            do {
                let stored = try library.add(data)
                if stored != name {
                    onLog("restore: picture \(name) re-hashed to \(stored)")
                }
            } catch {
                onLog("restore: picture \(name) not written: \(error)")
            }
        }
    }

    private func trashWallpapers(_ names: Set<String>) {
        let library = wallpaperLibrary
        for name in names where library.has(name) {
            do {
                try desktopMemory.trashWallpaper(library.url(of: name))
            } catch {
                onLog("wallpaper: \(name) not trashed: \(error)")
            }
        }
    }
}
