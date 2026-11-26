import AppKit

/// The look picker's Core doors (#3038): which look is worn, the
/// wear on ↵ and the ⌘S quick-save. The GUI reads and writes
/// through these alone, never `match` or the store beside them.
extension ShelfLook {
    /// The Lua the look picker's shortcut runs (#3038): the one
    /// spelling the seed and the Settings row share.
    public static let pickerLua = "look.show_picker()"
}

extension KiwiCore {
    /// The screen the picker covers: the one showing the focused
    /// Space, else none, and the GUI takes the pointer's.
    public func lookPickerScreen() -> NSScreen? {
        focusedScreen.flatMap(screen(for:))
    }

    /// The first bundled or saved look the live settings wear
    /// whole, colours included; nil when none does or the library
    /// cannot be read.
    public var wornLibraryLook: ShelfLook? {
        guard let saved = try? lookLibrary.libraryLooks() else {
            return nil
        }
        let settings = tiler.settings
        return (bundledLooks + saved.map(\.admitted)).first {
            $0.match(settings) == .applied
        }
    }

    /// The worn look when no library look matches it — the picker's
    /// "Current" card, which the GUI names; nil while the library
    /// cannot be read, so a saved look never shows as unsaved.
    public func unsavedWornLook() -> ShelfLook? {
        guard (try? lookLibrary.libraryLooks()) != nil,
            wornLibraryLook == nil
        else { return nil }
        return ShelfLook.current(named: "", in: tiler.settings)
    }

    /// Wears `look` for good: picked live, windows placed at once
    /// with no animation, and written into the live profile's file
    /// (with no profile live it lasts the session). `ready` runs at
    /// most once, after the frames are issued — a held pass
    /// (`MotionGate`) may still place them later. A look with a
    /// picture sets it through the pick's `lookWallpaper` write, and
    /// `ready` waits for macOS to report it on every screen (#3478);
    /// the caller caps that wait.
    public func wearPickedLook(
        _ look: ShelfLook,
        ready: @escaping @MainActor () -> Void
    ) {
        let before = tiler.settings.lookWallpaper
        let pick: SettingsEdit = { look.pick(into: &$0) }
        writeTourEditThrough(live: pick, stored: pick, animated: false)
        reassertWallpaper(ifUnchangedFrom: before)
        awaitWallpaperShown(ready: ready)
    }

    /// Saves the worn look under `base`, or the first free
    /// `base N`, and tells the library's readers.
    @discardableResult
    public func saveWornLook(base: String) throws -> ShelfLook {
        let look = try saveLook(
            named: freeLookName(base: base),
            from: tiler.settings
        )
        onLookLibraryChanged()
        return look
    }

    /// Renames a saved look from the picker and tells the library's
    /// readers, answering the name it stored; throws as
    /// `renameLook` refuses.
    @discardableResult
    public func renamePickedLook(
        from old: String,
        to new: String
    ) throws -> String {
        let stored = try renameLook(from: old, to: new)
        onLookLibraryChanged()
        return stored
    }
}
