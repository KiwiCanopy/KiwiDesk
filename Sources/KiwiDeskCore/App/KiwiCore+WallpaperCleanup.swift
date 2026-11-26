import Foundation

/// The library's cleanup (#3478 ▸ Cleanup): a picture goes to the
/// Trash once no look home names it. The stored homes are read by the
/// one `wallpaperNames(looks:config:profiles:)` walk, which a backup
/// reads too; cleanup adds the live settings and the shared look.
extension KiwiCore {
    /// Every library picture a stored look home names: the look
    /// library, `gui.json`'s shared look and settings, each profile.
    static func wallpaperNames(
        looks: [ShelfLook],
        config: GuiConfig?,
        profiles: [Profile]
    ) -> Set<String> {
        var names = Set(looks.flatMap { $0.wallpaper?.names ?? [] })
        names.formUnion(config?.look?.wallpaper?.names ?? [])
        names.formUnion(config?.settings.lookWallpaper?.names ?? [])
        for profile in profiles {
            names.formUnion(profile.settings.lookWallpaper?.names ?? [])
        }
        return names
    }

    /// Every library picture a look home names, the live one included.
    /// Reads the files, so it stays off the switch path.
    func namedWallpapers() -> Set<String> {
        var names = Self.wallpaperNames(
            looks: (try? lookLibrary.libraryLooks()) ?? [],
            config: guiConfigStore.load(),
            profiles: profiles.allProfiles()
        )
        names.formUnion(sharedLook?.wallpaper?.names ?? [])
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
    /// look names that arrived more than `grace` ago, which covers a
    /// picture synced in ahead of the `looks.json` naming it.
    func sweepWallpapers(grace: TimeInterval = 7 * 24 * 3600) {
        let library = wallpaperLibrary
        let named = namedWallpapers()
        let now = wallClock()
        let stale = library.names().filter { name in
            guard !named.contains(name) else { return false }
            let arrived = Self.arrival(of: library.url(of: name)) ?? now
            return now.timeIntervalSince(arrived) > grace
        }
        trashWallpapers(Set(stale))
    }

    /// When a file reached this folder: the later of its content and
    /// its attribute change, since a copy keeps the content date of
    /// the Mac it came from.
    static func arrival(of url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [
            .contentModificationDateKey, .attributeModificationDateKey,
        ])
        return [
            values?.contentModificationDate,
            values?.attributeModificationDate,
        ].compactMap { $0 }.max()
    }

    /// Writes a bundle's pictures, each re-hashed on the way in, so
    /// a name never disagrees with its bytes. A bundle from before
    /// pictures travelled carries none and leaves the library alone.
    func writeIncomingWallpapers(
        _ bundle: SetupBundle
    ) throws(SetupBundleError) {
        let library = wallpaperLibrary
        for (name, data) in bundle.wallpapers ?? [:] {
            do {
                let stored = try library.add(data)
                if stored != name {
                    onLog("restore: picture \(name) re-hashed to \(stored)")
                }
            } catch .couldNotWrite {
                throw .couldNotWrite(name: WallpaperLibrary.folderName)
            } catch {
                onLog("restore: picture \(name) not written: \(error)")
            }
        }
    }

    private func trashWallpapers(_ names: Set<String>) {
        let library = wallpaperLibrary
        for name in names where library.has(name) {
            do {
                try lookWallpaperSeams.trash(library.url(of: name))
            } catch {
                onLog("wallpaper: \(name) not trashed: \(error)")
            }
        }
    }
}
