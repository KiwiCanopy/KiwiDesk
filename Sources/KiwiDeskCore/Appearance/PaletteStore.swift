import Foundation

/// The palette library (#375): the seven built-ins plus the user's
/// saved palettes, persisted **globally** (not per-profile) in
/// `<config>/palettes.json`. Built-ins are read-only — they can't
/// be renamed, overwritten, or deleted; user palettes can. Names
/// are values inside the JSON (not file names), so there's no
/// path-traversal surface here.
///
/// Stateless and file-backed: every call reads or writes the file,
/// so a palette saved in one place is seen everywhere without a
/// cache to invalidate.
public final class PaletteStore {
    public enum StoreError: Error, Equatable {
        /// A user palette may not take a built-in's name.
        case reservedName(String)
        /// Rename/delete targeted a name no user palette has.
        case notFound(String)
        /// A rename would collide with another user palette's name.
        case duplicateName(String)
        /// The imported file wasn't a valid palette.
        case invalidFile
    }

    private let fileURL: URL

    /// Where the library lives. Public so a backup can name the
    /// file it replaces (#606) — this type is stateless, every
    /// read hitting the file, so a second instance over the same
    /// path is safe and is how Core reaches the library the GUI
    /// otherwise owns.
    public var url: URL { fileURL }

    /// `directory` is the config dir (`~/.config/KiwiDesk`); the
    /// library lives in `palettes.json` inside it.
    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("palettes.json")
    }

    // MARK: - Reads

    /// The built-in palettes (default first) — read-only.
    public func builtins() -> [ColorPalette] {
        PaletteCatalog.bundled()
    }

    /// The user's saved palettes, in saved order.
    public func userPalettes() -> [ColorPalette] {
        guard let data = try? Data(contentsOf: fileURL),
            let palettes = try? JSONDecoder().decode(
                [ColorPalette].self,
                from: data
            )
        else { return [] }
        return palettes
    }

    /// True if `name` belongs to a built-in (reserved).
    public func isBuiltinName(_ name: String) -> Bool {
        builtins().contains { $0.name == name }
    }

    /// True if a user palette already has `name`.
    public func hasUserPalette(_ name: String) -> Bool {
        userPalettes().contains { $0.name == name }
    }

    // MARK: - Writes (user palettes only)

    /// Adds `palette`, or overwrites the existing user palette of
    /// the same name (the caller confirms overwrite first). Throws
    /// `reservedName` if the name is a built-in's.
    public func save(_ palette: ColorPalette) throws {
        guard !isBuiltinName(palette.name) else {
            throw StoreError.reservedName(palette.name)
        }
        var palettes = userPalettes()
        if let index = palettes.firstIndex(where: {
            $0.name == palette.name
        }) {
            palettes[index] = palette
        } else {
            palettes.append(palette)
        }
        try write(palettes)
    }

    /// Replaces the whole user library — the restore half of a
    /// backup (#606).
    ///
    /// **This is the type's one bulk entry point, and the only one
    /// whose input is untrusted**, so it enforces every invariant
    /// the single-item paths enforce rather than only the first
    /// one a reviewer thought of. A backup is JSON on the user's
    /// disk; a hand-edited one can carry anything.
    ///
    /// - a name a **built-in** owns is dropped, which `save`
    ///   refuses one at a time (`reservedName`) — a shadow would
    ///   be invisible until the built-in stopped resolving;
    /// - a **duplicate** name is dropped, keeping the first, which
    ///   `rename` refuses (`duplicateName`) — the shelf keys tiles
    ///   by name, so twins are a collision rather than a
    ///   preference;
    /// - an **unknown colour key** is filtered out, exactly as
    ///   `importPalette` filters a hand-supplied file, so a typo
    ///   or a retired key cannot ride into the library.
    ///
    /// Dropping rather than throwing is deliberate: one bad entry
    /// must not fail a whole restore the user has already
    /// confirmed. The count says how many were refused.
    @discardableResult
    public func replaceUserPalettes(
        with palettes: [ColorPalette]
    ) throws -> Int {
        let known = Set(ColorPaletteKeys.all)
        var seen: Set<String> = []
        var admissible: [ColorPalette] = []
        for palette in palettes {
            guard !isBuiltinName(palette.name),
                seen.insert(palette.name).inserted
            else { continue }
            admissible.append(
                ColorPalette(
                    name: palette.name,
                    colors: palette.colors.filter {
                        known.contains($0.key)
                    }
                )
            )
        }
        try write(admissible)
        return palettes.count - admissible.count
    }

    /// Deletes the user palette named `name`.
    public func delete(_ name: String) throws {
        var palettes = userPalettes()
        guard
            let index = palettes.firstIndex(where: {
                $0.name == name
            })
        else {
            throw StoreError.notFound(name)
        }
        palettes.remove(at: index)
        try write(palettes)
    }

    /// Renames a user palette. Throws `notFound` if `from` isn't a
    /// user palette, `reservedName` if `to` is a built-in's name.
    public func rename(from: String, to: String) throws {
        guard !isBuiltinName(to) else {
            throw StoreError.reservedName(to)
        }
        // A rename onto another user palette's name would create a
        // duplicate — orphaning data and colliding the grid's id.
        guard to == from || !hasUserPalette(to) else {
            throw StoreError.duplicateName(to)
        }
        var palettes = userPalettes()
        guard
            let index = palettes.firstIndex(where: {
                $0.name == from
            })
        else {
            throw StoreError.notFound(from)
        }
        palettes[index].name = to
        try write(palettes)
    }

    // MARK: - Export / import

    /// Writes one palette to `url` (a Finder Save panel location).
    public func export(_ palette: ColorPalette, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        try encoder.encode(palette).write(to: url)
    }

    /// Reads one palette from `url` (a Finder Open panel location).
    /// Filters the colors to known paths so an alien file can't
    /// smuggle junk keys into the library.
    public func importPalette(from url: URL) throws -> ColorPalette {
        guard let data = try? Data(contentsOf: url),
            let raw = try? JSONDecoder().decode(
                ColorPalette.self,
                from: data
            )
        else {
            throw StoreError.invalidFile
        }
        let known = Set(ColorPaletteKeys.all)
        let colors = raw.colors.filter { known.contains($0.key) }
        return ColorPalette(name: raw.name, colors: colors)
    }

    private func write(_ palettes: [ColorPalette]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        // Atomic: a crash mid-flush must not truncate the library
        // — a corrupt file decodes to [] and the next save would
        // then rewrite it with only the new palette, losing it all.
        try encoder.encode(palettes).write(
            to: fileURL,
            options: .atomic
        )
    }
}
