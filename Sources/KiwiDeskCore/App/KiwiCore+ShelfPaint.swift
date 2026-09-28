import Foundation

/// The welcome tour's live look (#1720): a look or a palette
/// painted THROUGH — onto the running settings and, while a saved
/// profile is live, into that profile's file, non-adopting — so a
/// click is the whole act. The file half reads the stored settings
/// and paints them, never `persistProfile`'s live capture (#1179).
/// Only the look and palette keys move, in both halves.
extension KiwiCore {
    /// What a tour Revert paints back: the look and palette keys
    /// as they stood before the first paint, and whose profile.
    public struct ShelfPaintBaseline: Equatable, Sendable {
        let profile: String?
        let look: ShelfLook
        let colors: ColorPalette
    }

    /// Records the keys a later `restoreShelf` paints back.
    public func shelfPaintBaseline() -> ShelfPaintBaseline {
        let live = tiler.settings
        return ShelfPaintBaseline(
            profile: profiles.currentName,
            look: ShelfLook(
                name: "",
                palette: nil,
                style: LookKeys.extract(from: live)
            ),
            colors: ColorPalette(
                name: "",
                colors: ColorPaletteKeys.extract(from: live)
            )
        )
    }

    /// Paints `look`'s styling and its palette, or — with no
    /// look — `palette`'s colours alone, keeping the shape.
    public func paintShelf(look: ShelfLook?, palette: ColorPalette?) {
        paintShelfThrough { settings in
            if let look {
                look.apply(to: &settings, palette: palette)
            } else {
                palette?.apply(to: &settings)
            }
        }
    }

    /// Paints `baseline`'s keys back; refused once another profile
    /// is live, whose settings the baseline never described.
    @discardableResult
    public func restoreShelf(_ baseline: ShelfPaintBaseline) -> Bool {
        guard baseline.profile == profiles.currentName else {
            return false
        }
        paintShelfThrough {
            baseline.look.apply(to: &$0, palette: baseline.colors)
        }
        return true
    }

    private func paintShelfThrough(
        _ paint: (inout TilingSettings) -> Void
    ) {
        paint(&tiler.settings)
        if let name = profiles.currentName {
            writeStoredSettings(name, paint)
        }
        // An explicit apply (§5): a look can move the shelf's edge.
        retile(pass: .apply)
        onShelfPainted()
    }

    /// Non-adopting, like `overwriteProfile`: `current` and
    /// `dirty` stay as they were.
    private func writeStoredSettings(
        _ name: String,
        _ paint: (inout TilingSettings) -> Void
    ) {
        do {
            var profile = try profiles.read(name: name)
            paint(&profile.settings)
            try profiles.write(profile)
            refreshConfigIssues()
        } catch {
            onLog("tour look: profile \(name) not written: \(error)")
        }
    }
}
