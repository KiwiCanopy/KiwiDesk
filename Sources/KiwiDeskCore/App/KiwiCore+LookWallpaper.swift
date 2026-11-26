import AppKit
import Foundation

/// What a set of a look's picture did on one screen (#3478): Core
/// names it, the GUI narrates it.
public enum WallpaperSetOutcome: Equatable, Sendable {
    /// macOS took the set.
    case set
    /// The screen already shows this picture, so nothing was sent.
    case alreadyShown
    /// The screen shows a full-screen app's Space, where a set
    /// lands on a throwaway entry (the L4 spike).
    case fullScreenSpace
    /// The picture has not reached this Mac's library yet (sync).
    case notInLibrary
    /// macOS refused the set.
    case refused
}

/// Setting the worn look's picture (#3478): the one trigger is a
/// change of `TilingSettings.lookWallpaper`, whatever install wrote
/// it — a pick, a profile or Desktop switch, the shared look, the
/// picker — through `tiler.onLookWallpaper`. A look without a
/// picture clears the field and touches nothing.
extension KiwiCore {
    /// The pictures looks carry, in the config folder.
    public var wallpaperLibrary: WallpaperLibrary {
        WallpaperLibrary(configDirectory: configDirectory)
    }

    /// The copies macOS wears, in this Mac's folder.
    var wallpaperCopies: WallpaperMachineCopies {
        WallpaperMachineCopies(machineDirectory: machineDirectory)
    }

    /// Bootstrap-time: the one wiring of the trigger.
    func wireLookWallpaper() {
        tiler.onLookWallpaper = { [weak self] wallpaper in
            guard let self, self.desktopMemory.wallpaperArmed,
                let wallpaper
            else { return }
            self.setWallpaper(wallpaper)
        }
    }

    /// Sets `wallpaper` on each connected screen's current Desktop:
    /// screen k wears its own entry, else the lowest-numbered one,
    /// numbered by `liveScreenOrder` (#3647). Answers per screen
    /// number.
    @discardableResult
    func setWallpaper(
        _ wallpaper: LookWallpaper
    ) -> [Int: WallpaperSetOutcome] {
        let library = wallpaperLibrary
        let order = liveScreenOrder
        let desk = desktopMemory.wallpaper
        var wanted: [(DisplayID, Int, String)] = []
        for display in state.workspaces.allDisplays {
            guard
                let number = order.numbers(of: display.fingerprint).first,
                let name = wallpaper.name(forScreen: number)
            else { continue }
            wanted.append((display.id, number, name))
        }
        // Keep what a skipped screen still shows, or its Desktop
        // loses the file under it.
        let shown = Set(
            state.workspaces.allDisplays.compactMap {
                desk.current($0.id).flatMap(wallpaperCopies.libraryName)
            }
        )
        let names = Set(wanted.map(\.2).filter(library.has))
        let here = wallpaperCopies.keep(names.union(shown), from: library)
        var outcomes: [Int: WallpaperSetOutcome] = [:]
        for (display, number, name) in wanted {
            outcomes[number] = setWallpaper(
                name,
                on: display,
                available: here.contains(name)
            )
        }
        onLog("wallpaper: set \(outcomes.sorted { $0.key < $1.key })")
        return outcomes
    }

    private func setWallpaper(
        _ name: String,
        on display: DisplayID,
        available: Bool
    ) -> WallpaperSetOutcome {
        let desk = desktopMemory.wallpaper
        guard available else { return .notInLibrary }
        guard screenShowsUserSpace(on: display) else {
            return .fullScreenSpace
        }
        if let url = desk.current(display),
            wallpaperCopies.libraryName(of: url) == name
        {
            return .alreadyShown
        }
        return desk.set(wallpaperCopies.url(of: name), display)
            ? .set : .refused
    }

    /// Calls `ready` once every screen that should wear the live
    /// look's picture reports it, polling the URL read-back (235–480
    /// ms in the L4 spike); at once where there is none to wait for.
    /// The caller caps the wait.
    func awaitWallpaperShown(ready: @escaping @MainActor () -> Void) {
        guard desktopMemory.wallpaperArmed,
            let wallpaper = tiler.settings.lookWallpaper,
            wallpaperShown(wallpaper) == false
        else { return ready() }
        pollWallpaper(wallpaper, left: 12, ready: ready)
    }

    private func pollWallpaper(
        _ wallpaper: LookWallpaper,
        left: Int,
        ready: @escaping @MainActor () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            MainActor.assumeIsolated { [weak self] in
                guard let self else { return }
                guard left > 0, self.wallpaperShown(wallpaper) == false
                else { return ready() }
                self.pollWallpaper(wallpaper, left: left - 1, ready: ready)
            }
        }
    }

    /// Whether every user-Desktop screen shows its picture of
    /// `wallpaper`, read from the URLs alone.
    func wallpaperShown(_ wallpaper: LookWallpaper) -> Bool {
        let order = liveScreenOrder
        let desk = desktopMemory.wallpaper
        return state.workspaces.allDisplays.allSatisfy { display in
            guard screenShowsUserSpace(on: display.id),
                let number = order.numbers(of: display.fingerprint).first,
                let name = wallpaper.name(forScreen: number),
                wallpaperLibrary.has(name)
            else { return true }
            return desk.current(display.id)
                .flatMap(wallpaperCopies.libraryName) == name
        }
    }

    /// The number `screen` holds in `liveScreenOrder`, which picks
    /// its picture of a per-screen look; 1 where it holds none.
    public func screenNumber(of screen: NSScreen) -> Int {
        guard let id = screen.kiwiDisplayID,
            let display = state.workspaces.allDisplays.first(where: {
                $0.id == id
            })
        else { return 1 }
        return liveScreenOrder.numbers(of: display.fingerprint).first ?? 1
    }
}
