import Foundation

/// What Use Current Wallpaper found on one screen (#3478): Core
/// names it, the GUI narrates it.
public enum CurrentWallpaperOutcome: Error, Equatable, Sendable {
    /// The picture is stored for this screen.
    case stored
    /// The wallpaper is no picture file (a `.madesktop`, an Aerial,
    /// a colour, or a type looks do not carry).
    case notPictureFile
    /// The screen shows a full-screen app's Space; the look keeps
    /// what it held for this screen.
    case fullScreenSpace
    /// macOS refused the folder-access prompt.
    case accessRefused
    /// The file could not be read.
    case unreadable
}

/// Attaching, replacing and removing a saved look's picture
/// (#3478 ▸ menu ruling): the one door every route takes. A look
/// the screen wears takes the change at once.
extension KiwiCore {
    /// Stores `wallpaper` on saved look `name`, nil detaching every
    /// picture. Where the live settings wear that look, the live
    /// profile takes it too, which sets the picture (a detach sets
    /// nothing). Throws the store's refusal.
    public func setLookWallpaper(
        _ wallpaper: LookWallpaper?,
        of name: String
    ) throws {
        let library = lookLibrary
        guard
            var look = try library.libraryLooks().first(where: {
                $0.name == name
            })
        else { throw LookStore.StoreError.notFound(name) }
        let worn = look.admitted.match(tiler.settings) == .applied
        let replaced = look.wallpaper?.names ?? []
        look.wallpaper = wallpaper
        try library.save(look)
        onLookLibraryChanged()
        if worn {
            let admitted = wallpaper?.admitted
            tiler.settings.lookWallpaper = admitted
            writeThroughLiveProfile(.settings { $0.lookWallpaper = admitted })
        }
        trashUnnamedWallpapers(replaced)
    }

    /// Copies `data` into the library and attaches it to look `name`
    /// for every screen (Choose Wallpaper…, a drop). The over-32 MB
    /// question is the caller's, asked before (`largeBytes`).
    public func chooseLookWallpaper(
        _ data: Data,
        for name: String
    ) throws {
        let picture = try wallpaperLibrary.add(data)
        try setLookWallpaper(.all(picture), of: name)
    }

    /// Stores what each connected screen shows now on look `name`
    /// (Use Current Wallpaper): one picture when every screen shows
    /// the same file, one per screen number otherwise. Reading a
    /// file outside KiwiDesk's folders may raise macOS's
    /// folder-access prompt, a deliberate click's, so the reads run
    /// off the main actor. Answers per screen number.
    public func useCurrentWallpaper(
        for name: String
    ) async -> [Int: CurrentWallpaperOutcome] {
        let order = liveScreenOrder
        let desk = desktopMemory.wallpaper
        let held = userLooks.first { $0.name == name }?.wallpaper
        var picks: [Int: String] = [:]
        var outcomes: [Int: CurrentWallpaperOutcome] = [:]
        var reads: [(Int, URL)] = []
        for display in state.workspaces.allDisplays {
            guard let number = order.numbers(of: display.fingerprint).first
            else { continue }
            guard screenShowsUserSpace(on: display.id) else {
                outcomes[number] = .fullScreenSpace
                if let kept = held?.name(forScreen: number) {
                    picks[number] = kept
                }
                continue
            }
            guard let url = desk.current(display.id) else {
                outcomes[number] = .notPictureFile
                continue
            }
            if let own = wallpaperCopies.libraryName(of: url) {
                picks[number] = own
                outcomes[number] = .stored
            } else {
                reads.append((number, url))
            }
        }
        let library = wallpaperLibrary
        for (number, url) in reads {
            let read = Task.detached {
                Self.readPicture(at: url, into: library)
            }
            switch await read.value {
            case .success(let picture):
                picks[number] = picture
                outcomes[number] = .stored
            case .failure(let outcome):
                outcomes[number] = outcome
            }
        }
        if let wallpaper = Self.collapsed(picks) {
            do {
                try setLookWallpaper(wallpaper, of: name)
            } catch {
                onLog("use current wallpaper: \(name) not saved: \(error)")
                return outcomes.mapValues { _ in .unreadable }
            }
        }
        return outcomes
    }

    /// One picture where every entry names the same file, else the
    /// map; nil for no entry.
    nonisolated static func collapsed(_ picks: [Int: String]) -> LookWallpaper?
    {
        let names = Set(picks.values)
        guard let first = names.first else { return nil }
        return names.count == 1 ? .all(first) : .perScreen(picks)
    }

    /// Reads the wallpaper file at `url` into `library`.
    nonisolated static func readPicture(
        at url: URL,
        into library: WallpaperLibrary
    ) -> Result<String, CurrentWallpaperOutcome> {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError
            where error.code == .fileReadNoPermission
        {
            return .failure(.accessRefused)
        } catch {
            return .failure(.unreadable)
        }
        do {
            return .success(try library.add(data))
        } catch WallpaperLibrary.Refusal.notAPicture {
            return .failure(.notPictureFile)
        } catch {
            return .failure(.unreadable)
        }
    }
}
